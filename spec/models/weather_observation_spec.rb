require 'rails_helper'

RSpec.describe WeatherObservation, type: :model do
  describe 'バリデーション' do
    it '有効な属性を持つ場合は有効である' do
      weather_observation = build(:weather_observation)
      expect(weather_observation).to be_valid
    end

    it '日次ログがない場合は無効である' do
      weather_observation = build(:weather_observation, daily_log: nil)
      expect(weather_observation).not_to be_valid
    end

    it '気温が-90未満の場合は無効である' do
      weather_observation = build(:weather_observation, temperature_c: -91)
      expect(weather_observation).not_to be_valid
    end

    it '気温が60を超える場合は無効である' do
      weather_observation = build(:weather_observation, temperature_c: 61)
      expect(weather_observation).not_to be_valid
    end

    it '湿度が0未満の場合は無効である' do
      weather_observation = build(:weather_observation, humidity_pct: -1)
      expect(weather_observation).not_to be_valid
    end

    it '湿度が100を超える場合は無効である' do
      weather_observation = build(:weather_observation, humidity_pct: 101)
      expect(weather_observation).not_to be_valid
    end

    it '気圧が800未満の場合は無効である' do
      weather_observation = build(:weather_observation, pressure_hpa: 799)
      expect(weather_observation).not_to be_valid
    end

    it '気圧が1100を超える場合は無効である' do
      weather_observation = build(:weather_observation, pressure_hpa: 1101)
      expect(weather_observation).not_to be_valid
    end

    it '観測時刻がない場合は無効である' do
      weather_observation = build(:weather_observation, observed_at: nil)
      expect(weather_observation).not_to be_valid
    end
  end

  describe 'アソシエーション' do
    it '日次ログに属している' do
      weather_observation = create(:weather_observation)
      expect(weather_observation.daily_log).to be_present
    end
  end

  describe 'ファクトリー' do
    it '有効な天気観測データを作成する' do
      weather_observation = create(:weather_observation)
      expect(weather_observation).to be_persisted
      expect(weather_observation.daily_log).to be_present
      expect(weather_observation.temperature_c).to be_present
      expect(weather_observation.humidity_pct).to be_present
      expect(weather_observation.pressure_hpa).to be_present
    end

    it '寒い日の天気観測データを作成する' do
      weather_observation = create(:weather_observation, :cold)
      expect(weather_observation.temperature_c).to be < 5.0
    end

    it '暑い日の天気観測データを作成する' do
      weather_observation = create(:weather_observation, :hot)
      expect(weather_observation.temperature_c).to be > 25.0
    end

    it '低気圧の天気観測データを作成する' do
      weather_observation = create(:weather_observation, :low_pressure)
      expect(weather_observation.pressure_hpa).to be < 1000
    end

    it '高気圧の天気観測データを作成する' do
      weather_observation = create(:weather_observation, :high_pressure)
      expect(weather_observation.pressure_hpa).to be > 1000
    end
  end

  describe 'スナップショット' do
    it 'JSONデータを正しく保存する' do
      weather_observation = create(:weather_observation)
      expect(weather_observation.snapshot).to be_a(Hash)
      expect(weather_observation.snapshot['temperature']).to eq(weather_observation.temperature_c)
      expect(weather_observation.snapshot['humidity']).to eq(weather_observation.humidity_pct)
      expect(weather_observation.snapshot['pressure']).to eq(weather_observation.pressure_hpa)
    end
  end

  describe 'スコープ' do
    let!(:cold_observation) { create(:weather_observation, :cold) }
    let!(:hot_observation) { create(:weather_observation, :hot) }
    let!(:low_pressure_observation) { create(:weather_observation, :low_pressure) }

    it '低温の観測データを取得できる' do
      cold_observations = WeatherObservation.where('temperature_c < ?', 5.0)
      expect(cold_observations).to include(cold_observation)
    end

    it '高温の観測データを取得できる' do
      hot_observations = WeatherObservation.where('temperature_c > ?', 25.0)
      expect(hot_observations).to include(hot_observation)
    end

    it '低気圧の観測データを取得できる' do
      low_pressure_observations = WeatherObservation.where('pressure_hpa < ?', 1000)
      expect(low_pressure_observations).to include(low_pressure_observation)
    end
  end
end
