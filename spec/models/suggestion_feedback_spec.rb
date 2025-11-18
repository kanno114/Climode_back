require 'rails_helper'

RSpec.describe SuggestionFeedback, type: :model do
  describe 'バリデーション' do
    it '有効な属性を持つ場合は有効である' do
      suggestion_feedback = build(:suggestion_feedback)
      expect(suggestion_feedback).to be_valid
    end

    it 'daily_logがない場合は無効である' do
      suggestion_feedback = build(:suggestion_feedback, daily_log: nil)
      expect(suggestion_feedback).not_to be_valid
    end

    it 'suggestion_keyがない場合は無効である' do
      suggestion_feedback = build(:suggestion_feedback, suggestion_key: nil)
      expect(suggestion_feedback).not_to be_valid
    end

    it 'helpfulnessがない場合は無効である' do
      suggestion_feedback = build(:suggestion_feedback, helpfulness: nil)
      expect(suggestion_feedback).not_to be_valid
    end

    it '同じdaily_logとsuggestion_keyの組み合わせで重複は無効である' do
      daily_log = create(:daily_log)
      create(:suggestion_feedback,
             daily_log: daily_log,
             suggestion_key: "pressure_drop_signal_warning")
      suggestion_feedback = build(:suggestion_feedback,
                                  daily_log: daily_log,
                                  suggestion_key: "pressure_drop_signal_warning")
      expect(suggestion_feedback).not_to be_valid
    end

    it 'helpfulnessがtrueの場合は有効である' do
      suggestion_feedback = build(:suggestion_feedback, helpfulness: true)
      expect(suggestion_feedback).to be_valid
    end

    it 'helpfulnessがfalseの場合は有効である' do
      suggestion_feedback = build(:suggestion_feedback, helpfulness: false)
      expect(suggestion_feedback).to be_valid
    end
  end

  describe 'アソシエーション' do
    it 'daily_logに属する' do
      suggestion_feedback = create(:suggestion_feedback)
      expect(suggestion_feedback.daily_log).to be_present
    end

    it 'daily_logが削除されると削除される' do
      daily_log = create(:daily_log)
      suggestion_feedback = create(:suggestion_feedback, daily_log: daily_log)

      expect do
        daily_log.destroy
      end.to change { SuggestionFeedback.count }.by(-1)
    end
  end

  describe 'ファクトリー' do
    it '有効なフィードバックを作成する' do
      suggestion_feedback = create(:suggestion_feedback)
      expect(suggestion_feedback).to be_persisted
      expect(suggestion_feedback.daily_log).to be_present
      expect(suggestion_feedback.suggestion_key).to be_present
      expect(suggestion_feedback.helpfulness).to be_in([ true, false ])
    end

    it '役立たなかったフィードバックを作成する' do
      suggestion_feedback = create(:suggestion_feedback, :not_helpful)
      expect(suggestion_feedback.helpfulness).to be false
    end
  end
end
