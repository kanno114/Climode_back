require 'rails_helper'

RSpec.describe Weather::WeatherDataService do
  let(:prefecture) { create(:prefecture, :tokyo) }
  let(:date) { Date.current }
  let(:service) { described_class.new(prefecture, date) }

  describe '#fetch_weather_data' do
    context 'テスト環境の場合' do
      before do
        allow(Rails.env).to receive(:test?).and_return(true)
      end

      it 'ダミーデータを返す' do
        result = service.fetch_weather_data

        expect(result).to include(
          :temperature_c,
          :humidity_pct,
          :pressure_hpa,
          :observed_at,
          :snapshot
        )
        expect(result[:snapshot][:source]).to eq('dummy_data')
        expect(result[:snapshot][:prefecture_code]).to eq(prefecture.code)
        expect(result[:snapshot][:date]).to eq(date.to_s)
      end
    end

    context '本番環境の場合' do
      before do
        allow(Rails.env).to receive(:test?).and_return(false)
      end

      context 'API呼び出しが成功する場合' do
        let(:mock_response) do
          double(
            success?: true,
            body: {
              hourly: {
                time: [ '2024-01-01T09:00', '2024-01-01T10:00' ],
                temperature_2m: [ 20.5, 22.0 ],
                relative_humidity_2m: [ 65.0, 60.0 ],
                pressure_msl: [ 1013.2, 1012.8 ]
              }
            }.to_json
          )
        end

        before do
          allow(described_class).to receive(:get).and_return(mock_response)
        end

        it 'Open-Meteo APIから天気データを取得する' do
          result = service.fetch_weather_data

          expect(described_class).to have_received(:get).with(
            '/forecast',
            hash_including(
              query: hash_including(
                latitude: prefecture.centroid_lat,
                longitude: prefecture.centroid_lon,
                hourly: 'temperature_2m,relative_humidity_2m,pressure_msl',
                timezone: 'Asia/Tokyo',
                start_date: date.to_s,
                end_date: date.to_s
              )
            )
          )

          expect(result[:temperature_c]).to eq(20.5)
          expect(result[:humidity_pct]).to eq(65.0)
          expect(result[:pressure_hpa]).to eq(1013.2)
          expect(result[:snapshot][:source]).to eq('open_meteo_api')
        end
      end

      context 'API呼び出しが失敗する場合' do
        before do
          allow(described_class).to receive(:get).and_raise(StandardError.new('Network error'))
          allow(Rails.logger).to receive(:error)
        end

        it 'エラーログを出力してダミーデータを返す' do
          result = service.fetch_weather_data

          expect(Rails.logger).to have_received(:error).with(/Weather API error/)
          expect(result[:snapshot][:source]).to eq('dummy_data')
        end
      end

      context 'APIレスポンスが失敗の場合' do
        let(:mock_response) { double(success?: false) }

        before do
          allow(described_class).to receive(:get).and_return(mock_response)
        end

        it 'ダミーデータを返す' do
          result = service.fetch_weather_data

          expect(result[:snapshot][:source]).to eq('dummy_data')
        end
      end
    end
  end
end
