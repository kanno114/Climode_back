require 'rails_helper'

RSpec.describe 'Api::V1::Prefectures', type: :request do
  describe 'GET /api/v1/prefectures' do
    let!(:tokyo) { create(:prefecture, :tokyo) }
    let!(:osaka) { create(:prefecture, :osaka) }
    let!(:other_prefecture) { create(:prefecture, code: '01', name_ja: '北海道') }

    it 'すべての都道府県を取得し、200ステータスを返す' do
      get '/api/v1/prefectures'

      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response).to be_an(Array)
      # find_or_create_byにより複数のPrefectureが作成されている可能性があるため、
      # 最低限3つ以上存在することを確認
      expect(json_response.length).to be >= 3

      # 期待する都道府県が含まれていることを確認
      codes = json_response.map { |p| p['code'] }
      expect(codes).to include('01', '13', '27')
    end

    it '都道府県の情報が正しく含まれている' do
      get '/api/v1/prefectures'

      json_response = JSON.parse(response.body)
      tokyo_response = json_response.find { |p| p['code'] == '13' }

      expect(tokyo_response['id']).to eq(tokyo.id)
      expect(tokyo_response['code']).to eq('13')
      expect(tokyo_response['name_ja']).to eq('東京都')
      expect(tokyo_response['centroid_lat'].to_f).to eq(35.6762)
      expect(tokyo_response['centroid_lon'].to_f).to eq(139.6503)
    end
  end

  describe 'GET /api/v1/prefectures/:id' do
    let!(:tokyo) { create(:prefecture, :tokyo) }

    context '存在する都道府県の場合' do
      it '都道府県の詳細情報を取得し、200ステータスを返す' do
        get "/api/v1/prefectures/#{tokyo.id}"

        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response['id']).to eq(tokyo.id)
        expect(json_response['code']).to eq('13')
        expect(json_response['name_ja']).to eq('東京都')
        expect(json_response['centroid_lat'].to_f).to eq(35.6762)
        expect(json_response['centroid_lon'].to_f).to eq(139.6503)
      end
    end

    context '存在しない都道府県の場合' do
      it '404ステータスを返す' do
        get '/api/v1/prefectures/99999'

        expect(response).to have_http_status(:not_found)

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Prefecture not found')
      end
    end
  end
end
