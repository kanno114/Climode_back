require 'rails_helper'

RSpec.describe "Api::V1::SignalEvents", type: :request do
  include AuthHelper

  let(:user) { create(:user, prefecture: create(:prefecture)) }
  let(:token) { generate_jwt_token(user) }
  let(:headers) { { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" } }

  describe "GET /api/v1/signal_events/today" do
    context "認証済みユーザーの場合" do
      context "既存のシグナルイベントがある場合" do
        let!(:signal_event) { create(:signal_event, user: user, evaluated_at: Time.current) }

        it "当日のシグナルイベント一覧を返す" do
          get "/api/v1/signal_events/today", headers: headers

          expect(response).to have_http_status(:success)
          json = JSON.parse(response.body)
          expect(json).to be_an(Array)
          expect(json.length).to eq(1)
          expect(json[0]["id"]).to eq(signal_event.id)
          expect(json[0]["trigger_key"]).to eq(signal_event.trigger_key)
        end
      end

      context "シグナルイベントがない場合" do
        let!(:trigger) { Trigger.find_by(key: "pressure_drop") || create(:trigger, key: "pressure_drop", category: "env", is_active: true) }
        let!(:user_trigger) { create(:user_trigger, user: user, trigger: trigger) }
        let!(:weather_snapshot) do
          create(:weather_snapshot,
                 prefecture: user.prefecture,
                 date: Date.current,
                 metrics: { "pressure_drop_6h" => -7.0 })
        end

        it "env系トリガーを即時評価して返す" do
          allow(Weather::WeatherSnapshotService).to receive(:update_for_prefecture)

          get "/api/v1/signal_events/today", headers: headers

          expect(response).to have_http_status(:success)
          json = JSON.parse(response.body)
          expect(json).to be_an(Array)
        end
      end
    end

    context "未認証ユーザーの場合" do
      it "401エラーを返す" do
        get "/api/v1/signal_events/today"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
