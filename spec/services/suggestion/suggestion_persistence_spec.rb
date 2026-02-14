# frozen_string_literal: true

require "rails_helper"

RSpec.describe Suggestion::SuggestionPersistence do
  let(:daily_log) { create(:daily_log) }
  let(:suggestion_struct) do
    Suggestion::SuggestionEngine::Suggestion.new(
      key: "pressure_drop_signal_warning",
      title: "気圧変動に注意",
      message: "気圧が急変動しています。",
      tags: %w[weather pressure],
      severity: 2,
      triggers: {},
      category: "weather",
      concerns: []
    )
  end

  describe ".call" do
    it "提案をdaily_log_suggestionsに保存する" do
      expect do
        described_class.call(daily_log: daily_log, suggestions: [ suggestion_struct ])
      end.to change { DailyLogSuggestion.count }.by(1)

      rule = SuggestionRule.find_by(key: "pressure_drop_signal_warning")
      saved = daily_log.daily_log_suggestions.find_by(rule_id: rule.id)
      expect(saved).to be_present
      expect(saved.suggestion_rule.title).to eq("気圧変動に注意")
      expect(saved.suggestion_rule.message).to eq("気圧が急変動しています。")
    end

    it "空の提案配列の場合は何も保存しない" do
      expect do
        described_class.call(daily_log: daily_log, suggestions: [])
      end.not_to change { DailyLogSuggestion.count }
    end

    it "同一keyでupsertし、重複しない" do
      described_class.call(daily_log: daily_log, suggestions: [ suggestion_struct ])
      expect(daily_log.daily_log_suggestions.count).to eq(1)

      updated_struct = Suggestion::SuggestionEngine::Suggestion.new(
        key: "pressure_drop_signal_warning",
        title: "更新されたタイトル",
        message: "更新されたメッセージ",
        tags: [],
        severity: 3,
        triggers: {},
        category: "weather",
        concerns: []
      )
      described_class.call(daily_log: daily_log, suggestions: [ updated_struct ])

      expect(daily_log.daily_log_suggestions.count).to eq(1)
      # title/message は suggestion_rule に保存。upsert は position のみ更新
      rule = SuggestionRule.find_by(key: "pressure_drop_signal_warning")
      saved = daily_log.daily_log_suggestions.find_by(rule_id: rule.id)
      expect(saved).to be_present
    end
  end
end
