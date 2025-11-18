require "rails_helper"

RSpec.describe "Api::V1::DailyLogs", type: :request do
  let(:user) { create(:user) }
  let(:token) { generate_jwt_token(user) }
  let(:headers) do
    {
      "Authorization" => "Bearer #{token}",
      "Content-Type" => "application/json"
    }
  end
  let(:params) do
    {
      sleep_hours: 6.5,
      mood: 2,
      fatigue: -1
    }
  end

  describe "POST /api/v1/daily_logs/morning" do
    it "認証なしの場合は401を返す" do
      post "/api/v1/daily_logs/morning", params: params.to_json, headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "新規にDailyLogを作成する" do
      expect do
        post "/api/v1/daily_logs/morning", params: params.to_json, headers: headers
      end.to change { DailyLog.count }.by(1)

      expect(response).to have_http_status(:ok)
      expect(json_response["status"]).to eq("ok")

      daily_log = user.daily_logs.find_by(date: Date.current)
      expect(daily_log).not_to be_nil
      expect(daily_log.sleep_hours.to_f).to eq(6.5)
      expect(daily_log.mood).to eq(2)
      expect(daily_log.fatigue).to eq(-1)
      expect(daily_log.prefecture).to eq(user.prefecture)
    end

    context "既存のDailyLogがある場合" do
      let!(:daily_log) do
        create(:daily_log,
               user: user,
               prefecture: user.prefecture,
               date: Date.current,
               sleep_hours: 4.0,
               mood: -3,
               fatigue: -3)
      end

      it "既存レコードを更新する" do
        expect do
          post "/api/v1/daily_logs/morning", params: params.to_json, headers: headers
        end.not_to change { DailyLog.count }

        expect(response).to have_http_status(:ok)
        daily_log.reload
        expect(daily_log.sleep_hours.to_f).to eq(6.5)
        expect(daily_log.mood).to eq(2)
        expect(daily_log.fatigue).to eq(-1)
      end
    end

    context "ユーザーの都道府県が設定されていない場合" do
      let(:user_without_prefecture) { create(:user, :without_prefecture) }
      let(:token_without_prefecture) { generate_jwt_token(user_without_prefecture) }
      let(:headers_without_prefecture) do
        {
          "Authorization" => "Bearer #{token_without_prefecture}",
          "Content-Type" => "application/json"
        }
      end

      before do
        create(:prefecture, :tokyo)
      end

      it "東京都をフォールバックとして使用する" do
        post "/api/v1/daily_logs/morning",
             params: params.to_json,
             headers: headers_without_prefecture

        expect(response).to have_http_status(:ok)
        daily_log = user_without_prefecture.daily_logs.find_by(date: Date.current)
        expect(daily_log).not_to be_nil
        expect(daily_log.prefecture.code).to eq("13")
      end
    end
  end
end
