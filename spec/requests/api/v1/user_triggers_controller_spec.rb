require "rails_helper"

RSpec.describe "Api::V1::UserTriggers", type: :request do
  let(:user) { create(:user) }
  let(:token) { generate_jwt_token(user) }
  let(:headers) { { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" } }

  describe "GET /api/v1/user_triggers" do
    before { Trigger.delete_all }

    it "ユーザーのトリガー一覧を返す" do
      trigger = create(:trigger, key: "pressure_drop")
      user_trigger = create(:user_trigger, user: user, trigger: trigger)

      get "/api/v1/user_triggers", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first["id"]).to eq(user_trigger.id)
      expect(json.first["trigger"]["key"]).to eq("pressure_drop")
    end

    it "認証なしの場合は401になる" do
      get "/api/v1/user_triggers"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/user_triggers" do
    before { Trigger.delete_all }
    let(:trigger) { create(:trigger) }

    it "trigger_idで登録できる" do
      expect {
        post "/api/v1/user_triggers",
             params: { user_trigger: { trigger_id: trigger.id } }.to_json,
             headers: headers
      }.to change(UserTrigger, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["trigger"]["key"]).to eq(trigger.key)
    end

    it "trigger_keyで登録できる" do
      expect {
        post "/api/v1/user_triggers",
             params: { user_trigger: { trigger_key: trigger.key } }.to_json,
             headers: headers
      }.to change(UserTrigger, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "重複登録の場合は409を返す" do
      create(:user_trigger, user: user, trigger: trigger)

      post "/api/v1/user_triggers",
           params: { user_trigger: { trigger_id: trigger.id } }.to_json,
           headers: headers

      expect(response).to have_http_status(:conflict)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Trigger already registered")
    end

    it "存在しないトリガーIDの場合は404を返す" do
      post "/api/v1/user_triggers",
           params: { user_trigger: { trigger_id: 9999 } }.to_json,
           headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "非アクティブなトリガーは登録できない" do
      inactive = create(:trigger, :inactive)

      post "/api/v1/user_triggers",
           params: { user_trigger: { trigger_id: inactive.id } }.to_json,
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "認証なしの場合は401を返す" do
      post "/api/v1/user_triggers",
           params: { user_trigger: { trigger_id: trigger.id } }.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/user_triggers/:id" do
    before { Trigger.delete_all }
    let!(:user_trigger) { create(:user_trigger, user: user) }

    it "自分のトリガーを削除できる" do
      expect {
        delete "/api/v1/user_triggers/#{user_trigger.id}", headers: headers
      }.to change(UserTrigger, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "他ユーザーのトリガーは404を返す" do
      other_user_trigger = create(:user_trigger)

      delete "/api/v1/user_triggers/#{other_user_trigger.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "認証なしの場合は401を返す" do
      delete "/api/v1/user_triggers/#{user_trigger.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end

