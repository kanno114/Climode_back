require 'rails_helper'

RSpec.describe 'API::V1::DailyLogs', type: :request do
  let(:user) { create(:user) }
  let(:prefecture) { create(:prefecture, :tokyo) }
  let(:headers) { { 'User-Id' => user.id.to_s } }

  describe 'POST /api/v1/daily_logs' do
    let(:valid_params) do
      {
        daily_log: {
          date: Date.current.to_s,
          prefecture_id: prefecture.id,
          sleep_hours: 8.0,
          mood: 3,
          fatigue: -2,
          memo: 'テストメモ'
        }
      }
    end

    context '有効なパラメータの場合' do
      it 'DailyLogを作成し、天気データを自動取得する' do
        expect {
          post '/api/v1/daily_logs', params: valid_params, headers: headers
        }.to change(DailyLog, :count).by(1)
          .and change(WeatherObservation, :count).by(1)

        expect(response).to have_http_status(:created)
        
        # デバッグ情報を出力
        puts "Response status: #{response.status}"
        puts "Response body: #{response.body}"
        puts "Response weather_observation: #{response.body['weather_observation']}"
        puts "Response weather_observation temperature_c: #{response.body['weather_observation']['temperature_c']}"

        json = JSON.parse(response.body)
        expect(json['id']).to be_present
        expect(json['weather_observation']).to be_present
        expect(json['weather_observation']['temperature_c']).to be_present
      end
    end

    context '都道府県に座標がない場合' do
      let(:prefecture_without_coords) { create(:prefecture, centroid_lat: nil, centroid_lon: nil) }
      let(:params_without_coords) do
        {
          daily_log: {
            date: Date.current.to_s,
            prefecture_id: prefecture_without_coords.id,
            sleep_hours: 8.0
          }
        }
      end

      it 'DailyLogは作成されるが天気データは取得されない' do
        expect {
          post '/api/v1/daily_logs', params: params_without_coords, headers: headers
        }.to change(DailyLog, :count).by(1)
          .and change(WeatherObservation, :count).by(0)

        expect(response).to have_http_status(:created)
        
        json = JSON.parse(response.body)
        expect(json['weather_observation']).to be_nil
      end
    end
  end

  describe 'PUT /api/v1/daily_logs/:id' do
    let!(:daily_log) { create(:daily_log, user: user, prefecture: prefecture) }
    let(:new_prefecture) { create(:prefecture, :osaka) }

    context '都道府県を変更する場合' do
      let(:update_params) do
        {
          daily_log: {
            prefecture_id: new_prefecture.id,
            sleep_hours: 7.5
          }
        }
      end

      it '天気データが更新される' do
        expect {
          put "/api/v1/daily_logs/#{daily_log.id}", params: update_params, headers: headers
        }.to change { daily_log.reload.prefecture }.to(new_prefecture)

        expect(response).to have_http_status(:ok)
        
        json = JSON.parse(response.body)
        expect(json['weather_observation']).to be_present
      end
    end

    context '都道府県を変更しない場合' do
      let(:update_params) do
        {
          daily_log: {
            prefecture_id: prefecture.id,
            sleep_hours: 7.5,
            mood: 2
          }
        }
      end

      it '天気データは再取得されない' do
        original_weather_id = daily_log.weather_observation.id
        
        put "/api/v1/daily_logs/#{daily_log.id}", params: update_params, headers: headers
        
        expect(response).to have_http_status(:ok)
        expect(daily_log.reload.weather_observation.id).to eq(original_weather_id)
      end
    end
  end
end
