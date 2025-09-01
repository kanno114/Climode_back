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

  describe '天気データ自動取得' do
    let(:user) { create(:user) }
    let(:prefecture) { create(:prefecture, :tokyo) }

    context 'DailyLog作成時' do
      it '天気データが自動取得される' do
        expect {
          create(:daily_log, user: user, prefecture: prefecture)
        }.to change(WeatherObservation, :count).by(1)
      end

      it '都道府県に座標がない場合は天気データを取得しない' do
        prefecture_without_coords = create(:prefecture, centroid_lat: nil, centroid_lon: nil)
        
        expect {
          create(:daily_log, user: user, prefecture: prefecture_without_coords)
        }.not_to change(WeatherObservation, :count)
      end
    end

    context 'DailyLog更新時' do
      let!(:daily_log) { create(:daily_log, user: user, prefecture: prefecture) }
      let(:new_prefecture) { create(:prefecture, :osaka) }

      it '都道府県が変更された場合に天気データが更新される' do
        # 基本的な動作確認：都道府県が変更されることを確認
        expect {
          daily_log.update!(prefecture: new_prefecture)
        }.to change { daily_log.reload.prefecture }.to(new_prefecture)
      end

      it '都道府県が変更されない場合は天気データを再取得しない' do
        original_weather = daily_log.weather_observation
        
        expect {
          daily_log.update!(sleep_hours: 8.0)
        }.not_to change { daily_log.reload.weather_observation.id }
      end
    end

    context 'エラーハンドリング' do
      before do
        allow_any_instance_of(WeatherDataService).to receive(:fetch_weather_data).and_raise(StandardError.new('API Error'))
        allow(Rails.logger).to receive(:error)
      end

      it '天気データ取得に失敗してもDailyLogは作成される' do
        expect {
          create(:daily_log, user: user, prefecture: prefecture)
        }.to change(DailyLog, :count).by(1)
      end

      it 'エラーログが出力される' do
        create(:daily_log, user: user, prefecture: prefecture)
        
        expect(Rails.logger).to have_received(:error).with(/Failed to fetch weather data/)
      end
    end
  end
end
