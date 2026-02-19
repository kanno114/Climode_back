# frozen_string_literal: true

class SuggestionRule < ApplicationRecord
  has_many :daily_log_suggestions, foreign_key: :rule_id, dependent: :restrict_with_error
  has_many :suggestion_snapshots, foreign_key: :rule_id, dependent: :restrict_with_error
  has_many :suggestion_feedbacks, foreign_key: :rule_id, dependent: :restrict_with_error

  scope :enabled, -> { where(enabled: true) }

  validates :key, presence: true, uniqueness: true
  validates :title, presence: true
  validates :severity, presence: true
  validates :category, presence: true
  validates :condition, presence: true
end
