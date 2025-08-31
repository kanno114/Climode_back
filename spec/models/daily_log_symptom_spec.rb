require 'rails_helper'

RSpec.describe DailyLogSymptom, type: :model do
  describe 'バリデーション' do
    it '有効な属性を持つ場合は有効である' do
      daily_log_symptom = build(:daily_log_symptom)
      expect(daily_log_symptom).to be_valid
    end

    it '日次ログがない場合は無効である' do
      daily_log_symptom = build(:daily_log_symptom, daily_log: nil)
      expect(daily_log_symptom).not_to be_valid
    end

    it '症状がない場合は無効である' do
      daily_log_symptom = build(:daily_log_symptom, symptom: nil)
      expect(daily_log_symptom).not_to be_valid
    end

    it '同じ日次ログと症状の組み合わせで重複は無効である' do
      daily_log = create(:daily_log)
      symptom = create(:symptom)
      create(:daily_log_symptom, daily_log: daily_log, symptom: symptom)
      duplicate = build(:daily_log_symptom, daily_log: daily_log, symptom: symptom)
      expect(duplicate).not_to be_valid
    end
  end

  describe 'アソシエーション' do
    it '日次ログに属している' do
      daily_log_symptom = create(:daily_log_symptom)
      expect(daily_log_symptom.daily_log).to be_present
    end

    it '症状に属している' do
      daily_log_symptom = create(:daily_log_symptom)
      expect(daily_log_symptom.symptom).to be_present
    end
  end

  describe 'ファクトリー' do
    it '有効な日次ログ症状を作成する' do
      daily_log_symptom = create(:daily_log_symptom)
      expect(daily_log_symptom).to be_persisted
      expect(daily_log_symptom.daily_log).to be_present
      expect(daily_log_symptom.symptom).to be_present
    end
  end

  describe 'ユニーク制約' do
    let(:daily_log) { create(:daily_log) }
    let(:symptom) { create(:symptom) }

    it '同じ日次ログと症状の組み合わせは一意である' do
      create(:daily_log_symptom, daily_log: daily_log, symptom: symptom)
      expect {
        create(:daily_log_symptom, daily_log: daily_log, symptom: symptom)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it '異なる日次ログでは同じ症状を登録できる' do
      daily_log2 = create(:daily_log)
      create(:daily_log_symptom, daily_log: daily_log, symptom: symptom)
      daily_log_symptom2 = build(:daily_log_symptom, daily_log: daily_log2, symptom: symptom)
      expect(daily_log_symptom2).to be_valid
    end

    it '同じ日次ログでは異なる症状を登録できる' do
      symptom2 = create(:symptom)
      create(:daily_log_symptom, daily_log: daily_log, symptom: symptom)
      daily_log_symptom2 = build(:daily_log_symptom, daily_log: daily_log, symptom: symptom2)
      expect(daily_log_symptom2).to be_valid
    end
  end

  describe 'スコープ' do
    let(:daily_log) { create(:daily_log) }
    let(:symptom1) { create(:symptom, :headache) }
    let(:symptom2) { create(:symptom, :fatigue) }
    let!(:daily_log_symptom1) { create(:daily_log_symptom, daily_log: daily_log, symptom: symptom1) }
    let!(:daily_log_symptom2) { create(:daily_log_symptom, daily_log: daily_log, symptom: symptom2) }

    it '指定した日次ログの症状を取得できる' do
      symptoms = DailyLogSymptom.where(daily_log: daily_log)
      expect(symptoms).to include(daily_log_symptom1, daily_log_symptom2)
    end

    it '指定した症状の日次ログを取得できる' do
      daily_logs = DailyLogSymptom.where(symptom: symptom1)
      expect(daily_logs).to include(daily_log_symptom1)
    end
  end
end
