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

      saved = daily_log.daily_log_suggestions.find_by(suggestion_key: "pressure_drop_signal_warning")
      expect(saved).to be_present
      expect(saved.title).to eq("気圧変動に注意")
      expect(saved.message).to eq("気圧が急変動しています。")
      expect(saved.tags).to eq(%w[weather pressure])
      expect(saved.severity).to eq(2)
      expect(saved.category).to eq("weather")
    end

    it "空の提案配列の場合は何も保存しない" do
      expect do
        described_class.call(daily_log: daily_log, suggestions: [])
      end.not_to change { DailyLogSuggestion.count }
    end

    it "同一suggestion_keyでupsertし、重複しない" do
      described_class.call(daily_log: daily_log, suggestions: [ suggestion_struct ])
      expect(DailyLogSuggestion.count).to eq(1)

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

      expect(DailyLogSuggestion.count).to eq(1)
      saved = daily_log.daily_log_suggestions.find_by(suggestion_key: "pressure_drop_signal_warning")
      expect(saved.title).to eq("更新されたタイトル")
      expect(saved.message).to eq("更新されたメッセージ")
      expect(saved.severity).to eq(3)
    end
  end
end
