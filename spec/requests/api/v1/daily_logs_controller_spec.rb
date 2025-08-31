require 'rails_helper'

RSpec.describe 'Api::V1::DailyLogs', type: :request do
  let(:user) { create(:user) }
  let(:prefecture) { create(:prefecture) }
  let(:symptoms) { create_list(:symptom, 2) }

  describe 'GET /api/v1/daily_logs' do
    let!(:daily_logs) { create_list(:daily_log, 3, :with_weather_observation, :with_symptoms, user: user) }

    context '認証済みユーザーの場合' do
      it 'ユーザーの日次ログ一覧を取得し、200ステータスを返す' do
        get '/api/v1/daily_logs', headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        
        expect(json_response['daily_logs']).to be_an(Array)
        expect(json_response['daily_logs'].length).to eq(3)
        expect(json_response['pagination']).to be_present
        expect(json_response['pagination']['current_page']).to eq(1)
        expect(json_response['pagination']['total_count']).to eq(3)
      end

      it 'ページネーションが正しく動作する' do
        create_list(:daily_log, 15, :with_weather_observation, :with_symptoms, user: user) # 合計18件

        get '/api/v1/daily_logs?page=2&per_page=10', headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        
        expect(json_response['daily_logs'].length).to eq(8) # 2ページ目は8件
        expect(json_response['pagination']['current_page']).to eq(2)
        expect(json_response['pagination']['total_pages']).to eq(2)
      end

      it '日付の降順でソートされている' do
        get '/api/v1/daily_logs', headers: auth_headers(user)

        dates = json_response['daily_logs'].map { |log| log['date'] }
        expect(dates).to eq(dates.sort.reverse)
      end
    end

    context '未認証ユーザーの場合' do
      it '401ステータスを返す' do
        get '/api/v1/daily_logs'

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']).to eq('Unauthorized')
      end
    end
  end

  describe 'GET /api/v1/daily_logs/:id' do
    let!(:daily_log) { create(:daily_log, :with_weather_observation, :with_symptoms, user: user) }

    context '認証済みユーザーの場合' do
      it '指定した日次ログを取得し、200ステータスを返す' do
        get "/api/v1/daily_logs/#{daily_log.id}", headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        
        expect(json_response['id']).to eq(daily_log.id)
        expect(json_response['user_id']).to eq(user.id)
        expect(json_response['date']).to eq(daily_log.date.to_s)
      end

      it '関連データが含まれている' do
        get "/api/v1/daily_logs/#{daily_log.id}", headers: auth_headers(user)

        expect(json_response['prefecture']).to be_present
        expect(json_response['weather_observation']).to be_present
        expect(json_response['symptoms']).to be_an(Array)
      end
    end

    context '存在しない日次ログの場合' do
      it '404ステータスを返す' do
        get '/api/v1/daily_logs/99999', headers: auth_headers(user)

        expect(response).to have_http_status(:not_found)
      end
    end

    context '他のユーザーの日次ログの場合' do
      let(:other_user) { create(:user) }
      let!(:other_daily_log) { create(:daily_log, :with_weather_observation, :with_symptoms, user: other_user) }

      it '404ステータスを返す' do
        get "/api/v1/daily_logs/#{other_daily_log.id}", headers: auth_headers(user)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /api/v1/daily_logs' do
    let(:valid_params) do
      {
        daily_log: {
          date: Date.current.to_s,
          prefecture_id: prefecture.id,
          sleep_hours: 7.5,
          mood: 3,
          fatigue: -2,
          self_score: 80,
          memo: '今日は調子が良い',
          symptom_ids: symptoms.map(&:id)
        }
      }.to_json
    end

    let(:invalid_params) do
      {
        daily_log: {
          date: Date.current.to_s,
          prefecture_id: prefecture.id,
          sleep_hours: -1, # 無効な値
          mood: 10, # 無効な値
          fatigue: -10 # 無効な値
        }
      }.to_json
    end

    context '認証済みユーザーの場合' do
      it '日次ログを作成し、201ステータスを返す' do
        expect {
          post '/api/v1/daily_logs', params: valid_params, headers: auth_headers(user)
        }.to change(DailyLog, :count).by(1)

        expect(response).to have_http_status(:created)
        
        expect(json_response['user_id']).to eq(user.id)
        expect(json_response['date']).to eq(Date.current.to_s)
        expect(json_response['sleep_hours'].to_f).to eq(7.5)
        expect(json_response['mood'].to_i).to eq(3)
        expect(json_response['fatigue'].to_i).to eq(-2)
        expect(json_response['self_score'].to_i).to eq(80)
        expect(json_response['memo']).to eq('今日は調子が良い')
      end

      it '体調スコアが計算される' do
        post '/api/v1/daily_logs', params: valid_params, headers: auth_headers(user)

        expect(json_response['score']).to be_present
        expect(json_response['score']).to be_between(0, 100)
      end

      it '天気観測データが作成される' do
        expect {
          post '/api/v1/daily_logs', params: valid_params, headers: auth_headers(user)
        }.to change(WeatherObservation, :count).by(1)

        expect(json_response['weather_observation']).to be_present
      end

      it '症状が関連付けられる' do
        post '/api/v1/daily_logs', params: valid_params, headers: auth_headers(user)

        expect(json_response['symptoms'].length).to eq(2)
        expect(json_response['symptoms'].map { |s| s['id'] }).to match_array(symptoms.map(&:id))
      end
    end

    context '無効なパラメータの場合' do
      it '日次ログを作成せず、422ステータスを返す' do
        expect {
          post '/api/v1/daily_logs', params: invalid_params, headers: auth_headers(user)
        }.not_to change(DailyLog, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to be_present
      end
    end

    context '同じ日付の日次ログが既に存在する場合' do
      let!(:existing_log) { create(:daily_log, user: user, date: Date.current) }

      it '日次ログを作成せず、422ステータスを返す' do
        expect {
          post '/api/v1/daily_logs', params: valid_params, headers: auth_headers(user)
        }.not_to change(DailyLog, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to include('Date has already been taken')
      end
    end
  end

  describe 'PUT /api/v1/daily_logs/:id' do
    let!(:daily_log) { create(:daily_log, user: user) }
    let(:update_params) do
      {
        daily_log: {
          sleep_hours: 8.0,
          mood: 4,
          fatigue: -1,
          memo: '更新されたメモ'
        }
      }.to_json
    end

    context '認証済みユーザーの場合' do
      it '日次ログを更新し、200ステータスを返す' do
        put "/api/v1/daily_logs/#{daily_log.id}", params: update_params, headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        
        expect(json_response['sleep_hours'].to_f).to eq(8.0)
        expect(json_response['mood'].to_i).to eq(4)
        expect(json_response['fatigue'].to_i).to eq(-1)
        expect(json_response['memo']).to eq('更新されたメモ')
      end

      it '体調スコアが再計算される' do
        put "/api/v1/daily_logs/#{daily_log.id}", params: update_params, headers: auth_headers(user)

        expect(json_response['score']).to be_present
        expect(json_response['score']).to be_between(0, 100)
      end
    end

    context '無効なパラメータの場合' do
      let(:invalid_update_params) do
        {
          daily_log: {
            sleep_hours: 25, # 無効な値
            mood: 10 # 無効な値
          }
        }.to_json
      end

      it '日次ログを更新せず、422ステータスを返す' do
        put "/api/v1/daily_logs/#{daily_log.id}", params: invalid_update_params, headers: auth_headers(user)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to be_present
      end
    end
  end

  describe 'DELETE /api/v1/daily_logs/:id' do
    let!(:daily_log) { create(:daily_log, user: user) }

    context '認証済みユーザーの場合' do
      it '日次ログを削除し、204ステータスを返す' do
        expect {
          delete "/api/v1/daily_logs/#{daily_log.id}", headers: auth_headers(user)
        }.to change(DailyLog, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context '他のユーザーの日次ログの場合' do
      let(:other_user) { create(:user) }
      let!(:other_daily_log) { create(:daily_log, user: other_user) }

      it '404ステータスを返す' do
        delete "/api/v1/daily_logs/#{other_daily_log.id}", headers: auth_headers(user)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /api/v1/daily_logs/date/:date' do
    let!(:daily_log) { create(:daily_log, user: user, date: Date.current) }

    context '存在する日付の場合' do
      it '指定した日付の日次ログを取得し、200ステータスを返す' do
        get "/api/v1/daily_logs/date/#{Date.current}", headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        
        expect(json_response['id']).to eq(daily_log.id)
        expect(json_response['date']).to eq(Date.current.to_s)
      end
    end

    context '存在しない日付の場合' do
      it '404ステータスを返す' do
        get "/api/v1/daily_logs/date/#{Date.yesterday}", headers: auth_headers(user)

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']).to include('Daily log not found for date')
      end
    end
  end
end
