require 'rails_helper'

RSpec.describe DailyLog, type: :model do
  describe 'バリデーション' do
    it '有効な属性を持つ場合は有効である' do
      daily_log = build(:daily_log)
      expect(daily_log).to be_valid
    end

    it 'ユーザーがない場合は無効である' do
      daily_log = build(:daily_log, user: nil)
      expect(daily_log).not_to be_valid
    end

    it '都道府県がない場合は無効である' do
      daily_log = build(:daily_log, prefecture: nil)
      expect(daily_log).not_to be_valid
    end

    it '日付がない場合は無効である' do
      daily_log = build(:daily_log, date: nil)
      expect(daily_log).not_to be_valid
    end

    it '同じユーザーの同じ日付で重複は無効である' do
      user = create(:user)
      create(:daily_log, user: user, date: Date.current)
      daily_log = build(:daily_log, user: user, date: Date.current)
      expect(daily_log).not_to be_valid
    end

    it '睡眠時間が0未満の場合は無効である' do
      daily_log = build(:daily_log, sleep_hours: -1)
      expect(daily_log).not_to be_valid
    end

    it '睡眠時間が24を超える場合は無効である' do
      daily_log = build(:daily_log, sleep_hours: 25)
      expect(daily_log).not_to be_valid
    end

    it '気分が-5未満の場合は無効である' do
      daily_log = build(:daily_log, mood: -6)
      expect(daily_log).not_to be_valid
    end

    it '気分が5を超える場合は無効である' do
      daily_log = build(:daily_log, mood: 6)
      expect(daily_log).not_to be_valid
    end

    it '疲労度が-5未満の場合は無効である' do
      daily_log = build(:daily_log, fatigue: -6)
      expect(daily_log).not_to be_valid
    end

    it '疲労度が5を超える場合は無効である' do
      daily_log = build(:daily_log, fatigue: 6)
      expect(daily_log).not_to be_valid
    end

    it 'スコアが0未満の場合は無効である' do
      daily_log = build(:daily_log, score: -1)
      expect(daily_log).not_to be_valid
    end

    it 'スコアが100を超える場合は無効である' do
      daily_log = build(:daily_log, score: 101)
      expect(daily_log).not_to be_valid
    end

    it '自己評価スコアが0未満の場合は無効である' do
      daily_log = build(:daily_log, self_score: -1)
      expect(daily_log).not_to be_valid
    end

    it '自己評価スコアが100を超える場合は無効である' do
      daily_log = build(:daily_log, self_score: 101)
      expect(daily_log).not_to be_valid
    end
  end

  describe 'アソシエーション' do
    it 'ユーザーに属している' do
      daily_log = create(:daily_log)
      expect(daily_log.user).to be_present
    end

    it '都道府県に属している' do
      daily_log = create(:daily_log)
      expect(daily_log.prefecture).to be_present
    end

    it '天気観測データを持っている' do
      daily_log = create(:daily_log, :with_weather_observation)
      expect(daily_log.weather_observation).to be_present
    end

    it '複数の症状を持っている' do
      daily_log = create(:daily_log, :with_symptoms)
      expect(daily_log.symptoms).to be_present
    end
  end

  describe 'ファクトリー' do
    it '有効な日次ログを作成する' do
      daily_log = create(:daily_log)
      expect(daily_log).to be_persisted
      expect(daily_log.user).to be_present
      expect(daily_log.prefecture).to be_present
      expect(daily_log.date).to be_present
    end

    it '昨日の日次ログを作成する' do
      daily_log = create(:daily_log, :yesterday)
      expect(daily_log.date).to eq(Date.yesterday)
    end

    it '先週の日次ログを作成する' do
      daily_log = create(:daily_log, :last_week)
      expect(daily_log.date).to eq(1.week.ago.to_date)
    end

    it '天気観測データ付きの日次ログを作成する' do
      daily_log = create(:daily_log, :with_weather_observation)
      expect(daily_log.weather_observation).to be_present
      expect(daily_log.weather_observation.temperature_c).to be_present
    end

    it '症状付きの日次ログを作成する' do
      daily_log = create(:daily_log, :with_symptoms)
      expect(daily_log.symptoms).not_to be_empty
    end
  end

  describe 'スコープ' do
    let(:user) { create(:user) }
    let!(:today_log) { create(:daily_log, user: user, date: Date.current) }
    let!(:yesterday_log) { create(:daily_log, user: user, date: Date.yesterday) }
    let!(:last_week_log) { create(:daily_log, user: user, date: 1.week.ago.to_date) }

    it '指定した日付のログを取得できる' do
      expect(DailyLog.where(date: Date.current)).to include(today_log)
    end

    it '指定したユーザーのログを取得できる' do
      expect(DailyLog.where(user: user)).to include(today_log, yesterday_log, last_week_log)
    end
  end
end
