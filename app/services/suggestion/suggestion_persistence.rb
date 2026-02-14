# frozen_string_literal: true

module Suggestion
  # 提案（Suggestion）を daily_log_suggestions テーブルに保存する
  #
  # SuggestionEngine の結果を upsert し、同一 (daily_log_id, rule_id) で重複しないようにする
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

      rule_by_key = SuggestionRule.all.to_h { |r| [ r.key, r.id ] }
      records = @suggestions.each_with_index.filter_map do |s, idx|
        rule_id = rule_by_key[s.key]
        next unless rule_id

        {
          daily_log_id: @daily_log.id,
          rule_id: rule_id,
          position: idx,
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      return if records.blank?

      DailyLogSuggestion.upsert_all(
        records,
        unique_by: [ :daily_log_id, :rule_id ],
        update_only: %i[ position ]
      )
    end
  end
end
