require 'rails_helper'

RSpec.describe Symptom, type: :model do
  describe 'バリデーション' do
    it '有効な属性を持つ場合は有効である' do
      symptom = build(:symptom)
      expect(symptom).to be_valid
    end

    it 'コードがない場合は無効である' do
      symptom = build(:symptom, code: nil)
      expect(symptom).not_to be_valid
    end

    it '名前がない場合は無効である' do
      symptom = build(:symptom, name: nil)
      expect(symptom).not_to be_valid
    end

    it '重複したコードの場合は無効である' do
      create(:symptom, code: 'headache')
      symptom = build(:symptom, code: 'headache')
      expect(symptom).not_to be_valid
    end

    it '重複した名前の場合は無効である' do
      create(:symptom, name: '頭痛')
      symptom = build(:symptom, name: '頭痛')
      expect(symptom).not_to be_valid
    end
  end

  describe 'アソシエーション' do
    it '複数の日次ログ症状を持っている' do
      symptom = create(:symptom)
      daily_log_symptoms = create_list(:daily_log_symptom, 3, symptom: symptom)
      expect(symptom.daily_log_symptoms).to match_array(daily_log_symptoms)
    end

    it '複数の日次ログを持っている' do
      symptom = create(:symptom)
      daily_logs = create_list(:daily_log, 3)
      daily_logs.each do |daily_log|
        create(:daily_log_symptom, daily_log: daily_log, symptom: symptom)
      end
      expect(symptom.daily_logs).to match_array(daily_logs)
    end
  end

  describe 'ファクトリー' do
    it '有効な症状を作成する' do
      symptom = create(:symptom)
      expect(symptom).to be_persisted
      expect(symptom.code).to be_present
      expect(symptom.name).to be_present
    end

    it '頭痛の症状を作成する' do
      symptom = create(:symptom, :headache)
      expect(symptom.code).to eq('headache')
      expect(symptom.name).to eq('頭痛')
    end

    it '疲労の症状を作成する' do
      symptom = create(:symptom, :fatigue)
      expect(symptom.code).to eq('fatigue')
      expect(symptom.name).to eq('疲労')
    end

    it '吐き気の症状を作成する' do
      symptom = create(:symptom, :nausea)
      expect(symptom.code).to eq('nausea')
      expect(symptom.name).to eq('吐き気')
    end

    it 'めまいの症状を作成する' do
      symptom = create(:symptom, :dizziness)
      expect(symptom.code).to eq('dizziness')
      expect(symptom.name).to eq('めまい')
    end

    it '関節痛の症状を作成する' do
      symptom = create(:symptom, :joint_pain)
      expect(symptom.code).to eq('joint_pain')
      expect(symptom.name).to eq('関節痛')
    end
  end

  describe 'スコープ' do
    let!(:headache) { create(:symptom, :headache) }
    let!(:fatigue) { create(:symptom, :fatigue) }
    let!(:nausea) { create(:symptom, :nausea) }

    it '指定したコードの症状を取得できる' do
      found_symptom = Symptom.find_by(code: 'headache')
      expect(found_symptom).to eq(headache)
    end

    it '指定した名前の症状を取得できる' do
      found_symptom = Symptom.find_by(name: '疲労')
      expect(found_symptom).to eq(fatigue)
    end
  end
end
