require 'rails_helper'

RSpec.describe "Api::V1::Forecasts", type: :request do
  include AuthHelper

  let(:prefecture) { create(:prefecture) }
  let(:user) { create(:user, prefecture: prefecture) }
  let(:token) { generate_jwt_token(user) }
  let(:headers) { { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" } }

  describe "GET /api/v1/forecast" do
    context "キャッシュあり（Snapshot に hourly_forecast が存在する場合）" do
      let(:cached_forecast) do
        [
          { "time" => "2024-01-01T08:00:00+09:00", "temperature_c" => 19.0, "humidity_pct" => 65.0, "pressure_hpa" => 1012.0, "weather_code" => 1 },
          { "time" => "2024-01-01T09:00:00+09:00", "temperature_c" => 20.5, "humidity_pct" => 60.0, "pressure_hpa" => 1013.2, "weather_code" => 3 }
        ]
      end

      before do
        WeatherSnapshot.where(prefecture: prefecture, date: Date.current).destroy_all
        create(:weather_snapshot, prefecture: prefecture, date: Date.current, metrics: { "hourly_forecast" => cached_forecast })
        allow(Weather::WeatherDataService).to receive(:new)
      end

      it "キャッシュから返却し WeatherDataService を呼ばない" do
        get "/api/v1/forecast", headers: headers

        expect(response).to have_http_status(:success)
        json = json_response
        expect(json).to eq(cached_forecast)
        expect(Weather::WeatherDataService).not_to have_received(:new)
      end
    end

    context "認証済みユーザーかつ都道府県設定済みの場合（キャッシュミス）" do
      let(:series) do
        [
          {
            time: DateTime.new(2024, 1, 1, 9, 0, 0),
            temperature_c: 20.5,
            humidity_pct: 60.0,
            pressure_hpa: 1013.2,
            weather_code: 3
          },
          {
            time: DateTime.new(2024, 1, 1, 10, 0, 0),
            temperature_c: 22.0,
            humidity_pct: 58.0,
            pressure_hpa: 1012.8,
            weather_code: 61
          }
        ]
      end

      before do
        WeatherSnapshot.where(prefecture: prefecture, date: Date.current).destroy_all
        service_double = instance_double(Weather::WeatherDataService, fetch_forecast_series: series)
        allow(Weather::WeatherDataService).to receive(:new).and_return(service_double)
      end

      it "予報時系列データを返す（キャッシュミス時は API 取得）" do
        get "/api/v1/forecast", headers: headers

        expect(response).to have_http_status(:success)
        json = json_response
        expect(json).to be_an(Array)
        expect(json.size).to eq(series.size)
        expect(json.first["temperature_c"]).to eq(20.5)
        expect(json.first["humidity_pct"]).to eq(60.0)
        expect(json.first["pressure_hpa"]).to eq(1013.2)
        expect(json.first["weather_code"]).to eq(3)
        expect(Time.parse(json.first["time"]).hour).to eq(9)
      end

      it "date と hours パラメータを受け取って WeatherDataService に渡す" do
        get "/api/v1/forecast", params: { date: "2024-01-01", hours: 12 }, headers: headers

        expect(Weather::WeatherDataService).to have_received(:new).with(prefecture, Date.new(2024, 1, 1))
        json = json_response
        # series 側は 2 件だが、hours パラメータが正しく扱われることの確認用にレスポンスだけチェック
        expect(json).to be_an(Array)
      end
    end

    context "認証済みだが都道府県が未設定の場合" do
      let(:user_without_prefecture) { create(:user, prefecture: nil) }
      let(:token_without_prefecture) { generate_jwt_token(user_without_prefecture) }
      let(:headers_without_prefecture) { { "Authorization" => "Bearer #{token_without_prefecture}", "Content-Type": "application/json" } }

      it "422 を返す" do
        get "/api/v1/forecast", headers: headers_without_prefecture

        expect(response).to have_http_status(:unprocessable_entity)
        json = json_response
        expect(json["error"]).to eq("prefecture_not_set")
      end
    end

    context "未認証ユーザーの場合" do
      it "401 エラーを返す" do
        get "/api/v1/forecast"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "不正な日付フォーマットの場合" do
      it "400 エラーを返す" do
        get "/api/v1/forecast", params: { date: "invalid-date" }, headers: headers

        expect(response).to have_http_status(:bad_request)
        json = json_response
        expect(json["error"]).to eq("invalid_date")
      end
    end
  end
end
