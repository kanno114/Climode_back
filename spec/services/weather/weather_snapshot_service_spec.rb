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
  end
end
