require 'rails_helper'

RSpec.describe SignalEvent, type: :model do
  describe 'バリデーション' do
    it '有効な属性を持つ場合は有効である' do
      signal_event = build(:signal_event)
      expect(signal_event).to be_valid
    end

    it 'ユーザーがない場合は無効である' do
      signal_event = build(:signal_event, user: nil)
      expect(signal_event).not_to be_valid
    end

    it 'トリガーキーがない場合は無効である' do
      signal_event = build(:signal_event, trigger_key: nil)
      expect(signal_event).not_to be_valid
    end

    it 'カテゴリがない場合は無効である' do
      signal_event = build(:signal_event, category: nil)
      expect(signal_event).not_to be_valid
    end

    it 'カテゴリがenvまたはbodyでない場合は無効である' do
      signal_event = build(:signal_event, category: "invalid")
      expect(signal_event).not_to be_valid
    end

    it 'レベルがない場合は無効である' do
      signal_event = build(:signal_event, level: nil)
      expect(signal_event).not_to be_valid
    end

    it '優先度がない場合は無効である' do
      signal_event = build(:signal_event, priority: nil)
      expect(signal_event).not_to be_valid
    end

    it '評価時刻がない場合は無効である' do
      signal_event = build(:signal_event, evaluated_at: nil)
      expect(signal_event).not_to be_valid
    end

    it '同じユーザーの同じトリガーの同じ日付で重複は無効である' do
      user = create(:user)
      evaluated_at = Time.current
      create(:signal_event, user: user, trigger_key: "pressure_drop", evaluated_at: evaluated_at)
      signal_event = build(:signal_event, user: user, trigger_key: "pressure_drop", evaluated_at: evaluated_at)
      expect(signal_event).not_to be_valid
    end
  end

  describe 'アソシエーション' do
    it 'ユーザーに属している' do
      signal_event = create(:signal_event)
      expect(signal_event.user).to be_present
    end
  end

  describe 'スコープ' do
    let(:user) { create(:user) }
    let!(:today_event) { create(:signal_event, user: user, trigger_key: "trigger_today", evaluated_at: Time.current) }
    let!(:yesterday_event) { create(:signal_event, user: user, trigger_key: "trigger_yesterday", evaluated_at: 1.day.ago) }

    it '指定したユーザーのイベントを取得できる' do
      expect(SignalEvent.for_user(user)).to include(today_event, yesterday_event)
    end

    it '指定した日付のイベントを取得できる' do
      expect(SignalEvent.for_date(Date.current)).to include(today_event)
    end

    it '今日のイベントを取得できる' do
      expect(SignalEvent.today).to include(today_event)
    end

    it '指定したカテゴリのイベントを取得できる' do
      expect(SignalEvent.for_category("env")).to include(today_event)
    end

    it '優先度順に並べ替えられる' do
      # 異なるtrigger_keyを使用してユニーク制約を回避
      high_priority = create(:signal_event, user: user, trigger_key: "trigger_high", priority: 90)
      low_priority = create(:signal_event, user: user, trigger_key: "trigger_low", priority: 50)
      expect(SignalEvent.ordered_by_priority.first).to eq(high_priority)
    end
  end
end
