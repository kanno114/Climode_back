require 'rails_helper'

RSpec.describe 'Api::V1::Suggestions', type: :request do
  include AuthHelper

  let(:user) { create(:user, prefecture: create(:prefecture)) }
  let(:token) { generate_jwt_token(user) }
  let(:headers) { { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' } }

  describe 'GET /api/v1/suggestions' do
    context '認証済みユーザーの場合' do
      context 'DailyLogが存在する場合' do
        let!(:daily_log) do
          create(:daily_log,
                 user: user,
                 date: Date.current,
                 sleep_hours: 5.0,
                 mood: 3,
                 score: 60).tap do |log|
            create(:weather_observation, daily_log: log)
          end
        end
        let(:weather) { daily_log.weather_observation }

        before do
          weather.update!(
            temperature_c: 25.0,
            humidity_pct: 50.0,
            pressure_hpa: 1013.0
          )
        end

        it '提案一覧を返す' do
          get '/api/v1/suggestions', headers: headers

          expect(response).to have_http_status(:success)
          json = JSON.parse(response.body)
          expect(json).to be_an(Array)
        end

        it '提案オブジェクトが正しい構造を持つ' do
          get '/api/v1/suggestions', headers: headers

          json = JSON.parse(response.body)
          if json.length > 0
            suggestion = json.first
            expect(suggestion).to have_key('key')
            expect(suggestion).to have_key('title')
            expect(suggestion).to have_key('message')
            expect(suggestion).to have_key('tags')
            expect(suggestion).to have_key('severity')
            expect(suggestion).to have_key('triggers')
          end
        end

        it '最大3件まで返す' do
          daily_log.update!(sleep_hours: 5.0, score: 45)
          weather.update!(temperature_c: 36.0, humidity_pct: 75.0, pressure_hpa: 970.0)

          get '/api/v1/suggestions', headers: headers

          json = JSON.parse(response.body)
          expect(json.length).to be <= 3
        end

        it 'severityの高い順に返す' do
          daily_log.update!(sleep_hours: 5.0)
          weather.update!(temperature_c: 36.0, humidity_pct: 75.0)

          get '/api/v1/suggestions', headers: headers

          json = JSON.parse(response.body)
          if json.length > 1
            severities = json.map { |s| s['severity'] }
            expect(severities).to eq(severities.sort.reverse)
          end
        end

        it '提案がない場合でも空配列を返す' do
          daily_log.update!(sleep_hours: 7.5)
          weather.update!(temperature_c: 20.0, humidity_pct: 50.0, pressure_hpa: 1013.0)

          get '/api/v1/suggestions', headers: headers

          expect(response).to have_http_status(:success)
          json = JSON.parse(response.body)
          expect(json).to be_an(Array)
        end
      end

      context 'DailyLogが存在しない場合' do
        it '404エラーを返す' do
          get '/api/v1/suggestions', headers: headers

          expect(response).to have_http_status(:not_found)
          json = JSON.parse(response.body)
          expect(json).to have_key('error')
          expect(json['error']).to include('見つかりません')
        end
      end
    end

    context '未認証ユーザーの場合' do
      it '401エラーを返す' do
        get '/api/v1/suggestions'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end

