require "rails_helper"

RSpec.describe "Api::V1::Reports", type: :request do
  let(:user) { create(:user) }
  let(:token) { generate_jwt_token(user) }
  let(:headers) do
    {
      "Authorization" => "Bearer #{token}",
      "Content-Type" => "application/json"
    }
  end

  describe "GET /api/v1/reports/weekly" do
    context "認証なしの場合" do
      it "401ステータスを返す" do
        get "/api/v1/reports/weekly", headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "認証済みの場合" do
      let(:prefecture) { create(:prefecture, :tokyo) }
      let(:week_start) { Date.current.beginning_of_week(:monday) }
      let(:week_end) { week_start + 6.days }

      before do
        user.update!(prefecture: prefecture)
      end

      context "データがない場合" do
        it "空のデータを返す" do
          get "/api/v1/reports/weekly", headers: headers

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)

          expect(json["range"]["start"]).to eq(week_start.to_s)
          expect(json["range"]["end"]).to eq(week_end.to_s)
          expect(json["daily"]["avg_sleep_hours"]).to be_nil
          expect(json["daily"]["avg_mood"]).to be_nil
          expect(json["daily"]["avg_fatigue_level"]).to be_nil
          expect(json["feedback"]["helpfulness_rate"]).to be_nil
          expect(json["feedback"]["helpfulness_count"]["helpful"]).to eq(0)
          expect(json["feedback"]["helpfulness_count"]["not_helpful"]).to eq(0)
          expect(json["insight"]).to be_present
        end
      end

      context "データがある場合" do
        let!(:daily_log1) do
          create(:daily_log,
                 user: user,
                 prefecture: prefecture,
                 date: week_start + 1.day,
                 sleep_hours: 7.0,
                 mood: 2,
                 fatigue_level: 3)
        end
        let!(:daily_log2) do
          create(:daily_log,
                 user: user,
                 prefecture: prefecture,
                 date: week_start + 2.days,
                 sleep_hours: 6.5,
                 mood: 1,
                 fatigue_level: 4)
        end
        let!(:suggestion_feedback1) do
          create(:suggestion_feedback,
                 daily_log: daily_log1,
                 suggestion_key: "test_suggestion",
                 helpfulness: true)
        end
        let!(:suggestion_feedback2) do
          create(:suggestion_feedback,
                 daily_log: daily_log2,
                 suggestion_key: "test_suggestion2",
                 helpfulness: false)
        end

        it "週次レポートを返す" do
          get "/api/v1/reports/weekly", headers: headers

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)

          expect(json["range"]["start"]).to eq(week_start.to_s)
          expect(json["range"]["end"]).to eq(week_end.to_s)

          # 自己申告集計
          expect(json["daily"]["avg_sleep_hours"]).to eq(6.8)
          expect(json["daily"]["avg_mood"]).to eq(1.5)
          expect(json["daily"]["avg_fatigue_level"]).to eq(3.5)

          # フィードバック集計
          expect(json["feedback"]["helpfulness_rate"]).to eq(50.0)
          expect(json["feedback"]["helpfulness_count"]["helpful"]).to eq(1)
          expect(json["feedback"]["helpfulness_count"]["not_helpful"]).to eq(1)

          # インサイト
          expect(json["insight"]).to be_present
        end

        it "指定した週の開始日でレポートを返す" do
          target_week_start = week_start - 7.days
          get "/api/v1/reports/weekly?start=#{target_week_start}", headers: headers

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)

          expect(json["range"]["start"]).to eq(target_week_start.to_s)
          expect(json["range"]["end"]).to eq((target_week_start + 6.days).to_s)
        end

        it "無効な日付形式の場合は400を返す" do
          get "/api/v1/reports/weekly?start=invalid-date", headers: headers

          expect(response).to have_http_status(:bad_request)
          json = JSON.parse(response.body)
          expect(json["error"]).to include("無効な日付形式")
        end
      end
    end
  end
end
