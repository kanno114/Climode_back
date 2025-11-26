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
      fatigue: 3
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
      expect(daily_log.fatigue).to eq(3)
      expect(daily_log.prefecture).to eq(user.prefecture)
    end

    context "既存のDailyLogがある場合" do
      let!(:daily_log) do
        create(:daily_log,
               user: user,
               prefecture: user.prefecture,
               date: Date.current,
               sleep_hours: 4.0,
               mood: 2,
               fatigue: 2)
      end

      it "既存レコードを更新する" do
        expect do
          post "/api/v1/daily_logs/morning", params: params.to_json, headers: headers
        end.not_to change { DailyLog.count }

        expect(response).to have_http_status(:ok)
        daily_log.reload
        expect(daily_log.sleep_hours.to_f).to eq(6.5)
        expect(daily_log.mood).to eq(2)
        expect(daily_log.fatigue).to eq(3)
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

  describe "POST /api/v1/daily_logs/evening" do
    let(:evening_params) do
      {
        note: "今日は良い一日だった",
        suggestion_feedbacks: [
          {
            key: "pressure_drop_signal_warning",
            helpfulness: true
          },
          {
            key: "low_mood",
            helpfulness: false
          }
        ]
      }
    end

    it "認証なしの場合は401を返す" do
      post "/api/v1/daily_logs/evening",
           params: evening_params.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
    end

    context "既存のDailyLogがある場合" do
      let!(:daily_log) do
        create(:daily_log,
               user: user,
               prefecture: user.prefecture,
               date: Date.current)
      end

      it "DailyLogのnoteを更新し、suggestion_feedbacksを作成する" do
        expect do
          post "/api/v1/daily_logs/evening",
               params: evening_params.to_json,
               headers: headers
        end.to change { SuggestionFeedback.count }.by(2)

        expect(response).to have_http_status(:ok)
        expect(json_response["status"]).to eq("ok")

        daily_log.reload
        expect(daily_log.note).to eq("今日は良い一日だった")
        expect(daily_log.suggestion_feedbacks.count).to eq(2)

        feedback1 = daily_log.suggestion_feedbacks.find_by(suggestion_key: "pressure_drop_signal_warning")
        expect(feedback1).not_to be_nil
        expect(feedback1.helpfulness).to be true

        feedback2 = daily_log.suggestion_feedbacks.find_by(suggestion_key: "low_mood")
        expect(feedback2).not_to be_nil
        expect(feedback2.helpfulness).to be false
      end

      it "既存のsuggestion_feedbacksを削除してから新規作成する" do
        # 既存のフィードバックを作成
        create(:suggestion_feedback,
               daily_log: daily_log,
               suggestion_key: "pressure_drop_signal_warning",
               helpfulness: false)

        expect do
          post "/api/v1/daily_logs/evening",
               params: evening_params.to_json,
               headers: headers
        end.to change { SuggestionFeedback.count }.by(1) # 既存1つ削除 + 新規2つ作成 = +1

        daily_log.reload
        expect(daily_log.suggestion_feedbacks.count).to eq(2)

        feedback = daily_log.suggestion_feedbacks.find_by(suggestion_key: "pressure_drop_signal_warning")
        expect(feedback.helpfulness).to be true # 新しい値に更新されている
      end

      it "無効なhelpfulness値はスキップされる" do
        invalid_params = {
          note: "テスト",
          suggestion_feedbacks: [
            {
              key: "pressure_drop_signal_warning",
              helpfulness: true
            },
            {
              key: "low_mood",
              helpfulness: "invalid" # 無効な値
            }
          ]
        }

        expect do
          post "/api/v1/daily_logs/evening",
               params: invalid_params.to_json,
               headers: headers
        end.to change { SuggestionFeedback.count }.by(1) # 有効なもののみ作成

        daily_log.reload
        expect(daily_log.suggestion_feedbacks.count).to eq(1)
      end

      it "suggestion_feedbacksが空の場合は正常に処理される" do
        params_without_feedbacks = {
          note: "フィードバックなし"
        }

        expect do
          post "/api/v1/daily_logs/evening",
               params: params_without_feedbacks.to_json,
               headers: headers
        end.not_to change { SuggestionFeedback.count }

        expect(response).to have_http_status(:ok)
        daily_log.reload
        expect(daily_log.note).to eq("フィードバックなし")
      end
    end

    context "DailyLogが存在しない場合" do
      it "新規にDailyLogを作成する" do
        expect do
          post "/api/v1/daily_logs/evening",
               params: evening_params.to_json,
               headers: headers
        end.to change { DailyLog.count }.by(1)

        expect(response).to have_http_status(:ok)

        daily_log = user.daily_logs.find_by(date: Date.current)
        expect(daily_log).not_to be_nil
        expect(daily_log.note).to eq("今日は良い一日だった")
        expect(daily_log.suggestion_feedbacks.count).to eq(2)
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
        post "/api/v1/daily_logs/evening",
             params: evening_params.to_json,
             headers: headers_without_prefecture

        expect(response).to have_http_status(:ok)
        daily_log = user_without_prefecture.daily_logs.find_by(date: Date.current)
        expect(daily_log).not_to be_nil
        expect(daily_log.prefecture.code).to eq("13")
      end
    end
  end
end
