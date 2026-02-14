require 'rails_helper'

RSpec.describe Weather::WeatherDataService do
  let(:prefecture) { create(:prefecture, :tokyo) }
  let(:date) { Date.current }
  let(:service) { described_class.new(prefecture, date) }

  describe '#fetch_forecast_series' do
    context 'テスト環境の場合' do
      before do
        allow(Rails.env).to receive(:test?).and_return(true)
      end

      it '指定した件数のダミー時系列データを返す' do
        result = service.fetch_forecast_series(hours: 5)

        expect(result).to be_an(Array)
        expect(result.size).to eq(5)

        first = result.first
        expect(first).to include(
          :time,
          :temperature_c,
          :humidity_pct,
          :pressure_hpa,
          :weather_code
        )
        expect(first[:time]).to be_a(DateTime)
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
                time: [
                  '2024-01-01T09:00',
                  '2024-01-01T10:00'
                ],
                temperature_2m: [ 20.5, 22.0 ],
                relative_humidity_2m: [ 65.0, 60.0 ],
                pressure_msl: [ 1013.2, 1012.8 ],
                weather_code: [ 3, 61 ]
              }
            }.to_json
          )
        end

        before do
          allow(described_class).to receive(:get).and_return(mock_response)
        end

        it 'Open-Meteo APIから時系列データを取得する' do
          result = service.fetch_forecast_series(hours: 24)

          expect(described_class).to have_received(:get).with(
            '/forecast',
            hash_including(
              query: hash_including(
                latitude: prefecture.centroid_lat,
                longitude: prefecture.centroid_lon,
                hourly: 'temperature_2m,relative_humidity_2m,pressure_msl,weather_code',
                timezone: 'Asia/Tokyo',
                start_date: date.to_s,
                end_date: date.to_s
              )
            )
          )

          expect(result.size).to eq(2)
          first = result.first

          expect(first[:temperature_c]).to eq(20.5)
          expect(first[:humidity_pct]).to eq(65.0)
          expect(first[:pressure_hpa]).to eq(1013.2)
          expect(first[:weather_code]).to eq(3)
          expect(first[:time].hour).to eq(9)
        end

        it 'start_date/end_date を渡すと API の query にその日付が含まれる' do
          start_d = date - 1.day
          end_d = date
          service.fetch_forecast_series(hours: 48, start_date: start_d, end_date: end_d)

          expect(described_class).to have_received(:get).with(
            '/forecast',
            hash_including(
              query: hash_including(
                start_date: start_d.to_s,
                end_date: end_d.to_s
              )
            )
          )
        end
      end

      context 'API呼び出しが失敗する場合' do
        before do
          allow(described_class).to receive(:get).and_raise(StandardError.new('Network error'))
          allow(Rails.logger).to receive(:error)
        end

        it 'エラーログを出力してダミー時系列を返す' do
          result = service.fetch_forecast_series(hours: 3)

          expect(Rails.logger).to have_received(:error).with(/\[Weather\] Unexpected error \(series\)/)
          expect(result.size).to eq(3)
          expect(result.first[:time]).to be_a(DateTime)
        end
      end

      context 'APIレスポンスが失敗の場合' do
        let(:mock_response) { double(success?: false, code: 503) }

        before do
          allow(described_class).to receive(:get).and_return(mock_response)
          allow(Rails.logger).to receive(:warn)
        end

        it 'ダミー時系列データを返す' do
          result = service.fetch_forecast_series(hours: 4)

          expect(result.size).to eq(4)
          expect(result.first[:time]).to be_a(DateTime)
        end
      end
    end
  end
end
