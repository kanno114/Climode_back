require 'rails_helper'

RSpec.describe Weather::WeatherSnapshotService do
  let(:prefecture) { create(:prefecture, :tokyo) }
  let(:date) { Date.current }

  describe '.update_for_prefecture' do
    it 'WeatherSnapshotを作成または更新する' do
      # 既存のスナップショットを削除
      WeatherSnapshot.where(prefecture: prefecture, date: date).destroy_all

      allow_any_instance_of(described_class).to receive(:calculate_metrics).and_return({
        "pressure_drop_6h" => -6.4,
        "humidity_avg" => 85.2
      })

      expect {
        described_class.update_for_prefecture(prefecture, date)
      }.to change(WeatherSnapshot, :count).by(1)
    end

    it '既存のWeatherSnapshotを更新する' do
      # 既存のスナップショットを削除してから作成
      WeatherSnapshot.where(prefecture: prefecture, date: date).destroy_all
      snapshot = create(:weather_snapshot, prefecture: prefecture, date: date)

      allow_any_instance_of(described_class).to receive(:calculate_metrics).and_return({
        "pressure_drop_6h" => -7.0
      })

      described_class.update_for_prefecture(prefecture, date)
      snapshot.reload
      expect(snapshot.metrics["pressure_drop_6h"]).to eq(-7.0)
    end
  end

  describe '.update_all_prefectures' do
    let!(:prefecture1) { create(:prefecture) }
    let!(:prefecture2) { create(:prefecture) }

    it '全ての都道府県のWeatherSnapshotを更新する' do
      # 既存のスナップショットを削除
      WeatherSnapshot.where(date: date).destroy_all

      allow_any_instance_of(described_class).to receive(:calculate_metrics).and_return({
        "pressure_drop_6h" => -6.4
      })

      initial_count = WeatherSnapshot.count
      described_class.update_all_prefectures(date)

      # 全ての都道府県に対してスナップショットが作成されることを確認
      expect(WeatherSnapshot.where(date: date).count).to eq(Prefecture.count)
      expect(WeatherSnapshot.where(date: date, prefecture: prefecture1).exists?).to be true
      expect(WeatherSnapshot.where(date: date, prefecture: prefecture2).exists?).to be true
    end
  end

  describe '#update_snapshot' do
    let(:service) { described_class.new(prefecture, date) }

    context '気象データが取得できる場合' do
      before do
        # 既存のスナップショットを削除
        WeatherSnapshot.where(prefecture: prefecture, date: date).destroy_all

        allow(service).to receive(:calculate_metrics).and_return({
          "pressure_drop_6h" => -6.4,
          "humidity_avg" => 85.2
        })
      end

      it 'WeatherSnapshotを作成する' do
        expect {
          service.update_snapshot
        }.to change(WeatherSnapshot, :count).by(1)
      end
    end

    context '気象データが取得できない場合' do
      before do
        allow(service).to receive(:calculate_metrics).and_return({})
      end

      it 'WeatherSnapshotを作成しない' do
        expect {
          service.update_snapshot
        }.not_to change(WeatherSnapshot, :count)
      end
    end

    context '48h時系列から metrics と hourly_forecast を格納する場合' do
      # 48h 系列: 前日0時〜当日23時。当日8時, 前日8時, 当日2時, 前日20時 を含む
      let(:series_48h) do
        (0..47).map do |i|
          d = (date - 1.day) + (i / 24)
          h = i % 24
          temp = 21.0
          temp = 20.0 if d == date && h == 8   # 当日8時（基準）
          temp = 22.0 if d == date && h == 2   # 当日2時（6h前）
          temp = 26.0 if d == date - 1.day && h == 20 # 前日20時（12h前）
          press = 1012.0
          press = 1010.0 if d == date && h == 8
          press = 1015.0 if d == date && h == 2
          press = 1020.0 if d == date - 1.day && h == 8 # 前日8時（24h前）
          {
            time: d.to_datetime.change(hour: h, minute: 0, second: 0),
            temperature_c: temp,
            humidity_pct: 60.0,
            pressure_hpa: press,
            weather_code: 0
          }
        end
      end

      before do
        WeatherSnapshot.where(prefecture: prefecture, date: date).destroy_all
        data_service = instance_double(Weather::WeatherDataService, fetch_forecast_series: series_48h)
        allow(Weather::WeatherDataService).to receive(:new).with(prefecture, date).and_return(data_service)
      end

      it 'hourly_forecast と pressure_drop_6h 等が格納される' do
        expect { service.update_snapshot }.to change(WeatherSnapshot, :count).by(1)

        snapshot = WeatherSnapshot.find_by(prefecture: prefecture, date: date)
        expect(snapshot.metrics["hourly_forecast"]).to be_present
        expect(snapshot.metrics["hourly_forecast"]).to be_an(Array)
        expect(snapshot.metrics["hourly_forecast"].first).to include("time", "temperature_c", "humidity_pct", "pressure_hpa", "weather_code")

        # 当日8時 1010, 当日2時 1015 → pressure_drop_6h = -5.0
        expect(snapshot.metrics["pressure_drop_6h"]).to eq(-5.0)
        # 当日8時 1010, 前日8時 1020 → pressure_drop_24h = -10.0
        expect(snapshot.metrics["pressure_drop_24h"]).to eq(-10.0)
        # 当日8時 20, 当日2時 22 → temperature_drop_6h = -2.0
        expect(snapshot.metrics["temperature_drop_6h"]).to eq(-2.0)
        # 当日8時 20, 前日20時 26 → temperature_drop_12h = -6.0
        expect(snapshot.metrics["temperature_drop_12h"]).to eq(-6.0)
      end

      context '起床時間帯の気圧差メトリクス' do
        it 'max_pressure_drop_1h_awake と low_pressure_duration_* を計算する' do
          service.update_snapshot

          snapshot = WeatherSnapshot.find_by(prefecture: prefecture, date: date)
          metrics = snapshot.metrics

          # 起床時間帯は 8:00〜22:00 としており、series_48h ではすべて 1012hPa なので
          # 1時間あたりの気圧変化は 0、低気圧継続時間は 0 となる想定
          expect(metrics).to have_key("max_pressure_drop_1h_awake")
          expect(metrics["low_pressure_duration_1003h"]).to be_a(Float)
          expect(metrics["low_pressure_duration_1007h"]).to be_a(Float)
        end
      end
    end
  end
end
