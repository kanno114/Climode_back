require "rails_helper"

RSpec.describe "Api::V1::Triggers", type: :request do
  let(:user) { create(:user) }
  let(:token) { generate_jwt_token(user) }
  let(:headers) { { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" } }

  describe "GET /api/v1/triggers" do
    before do
      UserTrigger.delete_all
      Trigger.delete_all
      create(:trigger, key: "pressure_drop", label: "気圧低下", category: "env")
      create(:trigger, key: "sleep_shortage", label: "寝不足", category: "body")
      create(:trigger, :inactive, key: "deprecated", label: "非表示", category: "env")
    end

    it "認証なしの場合は401を返す" do
      get "/api/v1/triggers"
      expect(response).to have_http_status(:unauthorized)
    end

    it "アクティブなトリガーのみを返す" do
      get "/api/v1/triggers", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json).to be_an(Array)
      expect(json.size).to eq(2)
      keys = json.map { |t| t["key"] }
      expect(keys).to contain_exactly("pressure_drop", "sleep_shortage")
      expect(json.first).to include("label", "category", "version", "rule")
    end
  end
end
