# frozen_string_literal: true

class DailyLogSuggestion < ApplicationRecord
  belongs_to :daily_log
  belongs_to :suggestion_rule, foreign_key: :rule_id

  validates :rule_id, uniqueness: { scope: :daily_log_id }
end
