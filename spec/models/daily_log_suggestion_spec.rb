# frozen_string_literal: true

require "rails_helper"

RSpec.describe DailyLogSuggestion, type: :model do
  describe "バリデーション" do
    it "有効な属性を持つ場合は有効である" do
      daily_log_suggestion = build(:daily_log_suggestion)
      expect(daily_log_suggestion).to be_valid
    end

    it "daily_logがない場合は無効である" do
      daily_log_suggestion = build(:daily_log_suggestion, daily_log: nil)
      expect(daily_log_suggestion).not_to be_valid
    end

    it "suggestion_ruleがない場合は無効である" do
      daily_log_suggestion = build(:daily_log_suggestion, suggestion_rule: nil)
      expect(daily_log_suggestion).not_to be_valid
    end

    it "同じdaily_logとrule_idの組み合わせで重複は無効である" do
      daily_log = create(:daily_log)
      rule = SuggestionRule.find_by!(key: "pressure_drop_signal_warning")
      create(:daily_log_suggestion, daily_log: daily_log, suggestion_rule: rule)
      duplicate = build(:daily_log_suggestion, daily_log: daily_log, suggestion_rule: rule)
      expect(duplicate).not_to be_valid
    end
  end

  describe "アソシエーション" do
    it "daily_logに属する" do
      daily_log_suggestion = create(:daily_log_suggestion)
      expect(daily_log_suggestion.daily_log).to be_present
    end

    it "suggestion_ruleに属する" do
      daily_log_suggestion = create(:daily_log_suggestion)
      expect(daily_log_suggestion.suggestion_rule).to be_present
    end

    it "daily_logが削除されると削除される" do
      daily_log = create(:daily_log)
      daily_log_suggestion = create(:daily_log_suggestion, daily_log: daily_log)

      expect do
        daily_log.destroy
      end.to change { described_class.count }.by(-1)
    end
  end

  describe "ファクトリー" do
    it "有効な提案を作成する" do
      daily_log_suggestion = create(:daily_log_suggestion)
      expect(daily_log_suggestion).to be_persisted
      expect(daily_log_suggestion.daily_log).to be_present
      expect(daily_log_suggestion.suggestion_rule).to be_present
    end
  end
end
