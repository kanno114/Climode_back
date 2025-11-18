require 'rails_helper'

RSpec.describe WeatherSnapshot, type: :model do
  describe 'バリデーション' do
    it '有効な属性を持つ場合は有効である' do
      weather_snapshot = build(:weather_snapshot)
      expect(weather_snapshot).to be_valid
    end

    it '都道府県がない場合は無効である' do
      weather_snapshot = build(:weather_snapshot, prefecture: nil)
      expect(weather_snapshot).not_to be_valid
    end

    it '日付がない場合は無効である' do
      weather_snapshot = build(:weather_snapshot, date: nil)
      expect(weather_snapshot).not_to be_valid
    end

    it '同じ都道府県の同じ日付で重複は無効である' do
      prefecture = create(:prefecture)
      create(:weather_snapshot, prefecture: prefecture, date: Date.current)
      weather_snapshot = build(:weather_snapshot, prefecture: prefecture, date: Date.current)
      expect(weather_snapshot).not_to be_valid
    end
  end

  describe 'アソシエーション' do
    it '都道府県に属している' do
      weather_snapshot = create(:weather_snapshot)
      expect(weather_snapshot.prefecture).to be_present
    end
  end

  describe 'スコープ' do
    let(:prefecture) { create(:prefecture) }
    let!(:today_snapshot) { create(:weather_snapshot, prefecture: prefecture, date: Date.current) }
    let!(:yesterday_snapshot) { create(:weather_snapshot, prefecture: prefecture, date: Date.yesterday) }

    it '指定した日付のスナップショットを取得できる' do
      expect(WeatherSnapshot.for_date(Date.current)).to include(today_snapshot)
    end

    it '指定した都道府県のスナップショットを取得できる' do
      expect(WeatherSnapshot.for_prefecture(prefecture)).to include(today_snapshot, yesterday_snapshot)
    end
  end
end

