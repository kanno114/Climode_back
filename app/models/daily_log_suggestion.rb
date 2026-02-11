# frozen_string_literal: true

class DailyLogSuggestion < ApplicationRecord
  belongs_to :daily_log

  validates :suggestion_key, presence: true
  validates :title, presence: true
  validates :severity, presence: true
  validates :category, presence: true
  validates :suggestion_key, uniqueness: { scope: :daily_log_id }
end
