class SuggestionSnapshot < ApplicationRecord
  belongs_to :prefecture
  belongs_to :suggestion_rule, foreign_key: :rule_id

  validates :date, presence: true
  validates :rule_id, presence: true

  scope :for_date, ->(date) { where(date: date) }
  scope :for_prefecture, ->(pref) { where(prefecture_id: pref.respond_to?(:id) ? pref.id : pref) }
end
