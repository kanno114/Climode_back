# frozen_string_literal: true

module Suggestion
  # 提案（Suggestion）を daily_log_suggestions テーブルに保存する
  #
  # SuggestionEngine の結果を upsert し、同一 (daily_log_id, suggestion_key) で重複しないようにする
  class SuggestionPersistence
    def self.call(daily_log:, suggestions:)
      new(daily_log: daily_log, suggestions: suggestions).call
    end

    def initialize(daily_log:, suggestions:)
      @daily_log = daily_log
      @suggestions = suggestions
    end

    def call
      return if @suggestions.blank?

      records = @suggestions.each_with_index.map do |s, idx|
        {
          daily_log_id: @daily_log.id,
          suggestion_key: s.key,
          title: s.title,
          message: s.message,
          tags: (s.tags || []),
          severity: s.severity,
          category: s.category,
          position: idx,
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      DailyLogSuggestion.upsert_all(
        records,
        unique_by: [ :daily_log_id, :suggestion_key ],
        update_only: %i[ title message tags severity category position ]
      )
    end
  end
end
