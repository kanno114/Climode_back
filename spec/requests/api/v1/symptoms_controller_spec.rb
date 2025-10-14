require 'rails_helper'

RSpec.describe 'Api::V1::Symptoms', type: :request do
  describe 'GET /api/v1/symptoms' do
    let!(:headache) { create(:symptom, :headache) }
    let!(:fatigue) { create(:symptom, :fatigue) }
    let!(:nausea) { create(:symptom, :nausea) }

    it 'すべての症状を取得し、200ステータスを返す' do
      get '/api/v1/symptoms'

      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response).to be_an(Array)
      expect(json_response.length).to eq(3)



      # 名前順でソートされていることを確認（順序は重要でない）
      expect(json_response.map { |s| s['name'] }).to include('頭痛', '吐き気', '疲労')
    end

    it '症状の情報が正しく含まれている' do
      get '/api/v1/symptoms'

      json_response = JSON.parse(response.body)
      headache_response = json_response.find { |s| s['code'] == 'headache' }

      expect(headache_response['id']).to eq(headache.id)
      expect(headache_response['code']).to eq('headache')
      expect(headache_response['name']).to eq('頭痛')
    end
  end

  describe 'GET /api/v1/symptoms/:id' do
    let!(:headache) { create(:symptom, :headache) }

    context '存在する症状の場合' do
      it '症状の詳細情報を取得し、200ステータスを返す' do
        get "/api/v1/symptoms/#{headache.id}"

        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response['id']).to eq(headache.id)
        expect(json_response['code']).to eq('headache')
        expect(json_response['name']).to eq('頭痛')
      end
    end

    context '存在しない症状の場合' do
      it '404ステータスを返す' do
        get '/api/v1/symptoms/99999'

        expect(response).to have_http_status(:not_found)

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Symptom not found')
      end
    end
  end
end
