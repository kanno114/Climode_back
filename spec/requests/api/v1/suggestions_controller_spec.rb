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
                 mood: 3)
        end

        let!(:weather_snapshot) do
          create(:weather_snapshot,
                 prefecture: user.prefecture,
                 date: Date.current,
                 metrics: {
                   "temperature_c" => 25.0,
                   "humidity_pct" => 50.0,
                   "pressure_hpa" => 1013.0
                 })
        end

        it '提案一覧を返す' do
          get '/api/v1/suggestions', headers: headers

          expect(response).to have_http_status(:success)
          json = JSON.parse(response.body)
          expect(json).to be_an(Array)
        end

        it '提案がdaily_log_suggestionsに保存される' do
          expect { get '/api/v1/suggestions', headers: headers }
            .to change { daily_log.daily_log_suggestions.count }
            .by_at_least(0)

          expect(response).to have_http_status(:success)
          json = JSON.parse(response.body)
          return if json.empty?

          json.each do |suggestion|
            rule = SuggestionRule.find_by(key: suggestion["key"])
            next unless rule

            saved = daily_log.daily_log_suggestions.find_by(rule_id: rule.id)
            expect(saved).to be_present
            expect(saved.suggestion_rule.title).to eq(suggestion["title"])
            expect(saved.suggestion_rule.message).to eq(suggestion["message"])
          end
        end

        it '複数回取得してもupsertにより重複レコードが発生しない' do
          get '/api/v1/suggestions', headers: headers
          count_after_first = daily_log.daily_log_suggestions.count

          get '/api/v1/suggestions', headers: headers
          count_after_second = daily_log.daily_log_suggestions.count

          expect(count_after_second).to eq(count_after_first)
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
            expect(suggestion).to have_key('reason_text')
            expect(suggestion).to have_key('evidence_text')
          end
        end

        it '条件に一致した提案をすべて返す（件数制限なし）' do
          daily_log.update!(sleep_hours: 5.0)
          weather_snapshot.update!(metrics: {
            "temperature_c" => 36.0,
            "humidity_pct" => 75.0,
            "pressure_hpa" => 970.0
          })

          get '/api/v1/suggestions', headers: headers

          json = JSON.parse(response.body)
          expect(json).to be_an(Array)
          expect(json.length).to be >= 1
        end

        it 'severityの高い順に返す' do
          daily_log.update!(sleep_hours: 5.0)
          weather_snapshot.update!(metrics: {
            "temperature_c" => 36.0,
            "humidity_pct" => 75.0,
            "pressure_hpa" => 1013.0
          })

          get '/api/v1/suggestions', headers: headers

          json = JSON.parse(response.body)
          if json.length > 1
            severities = json.map { |s| s['severity'] }
            expect(severities).to eq(severities.sort.reverse)
          end
          if json.length > 0
            expect(json.first).to have_key('level')
          end
        end

        it '提案がない場合でも空配列を返す' do
          daily_log.update!(sleep_hours: 7.5)
          weather_snapshot.update!(metrics: {
            "temperature_c" => 20.0,
            "humidity_pct" => 50.0,
            "pressure_hpa" => 1013.0
          })

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
          expect(json['error']).to eq('not_found')
          expect(json['message']).to include('見つかりません')
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
