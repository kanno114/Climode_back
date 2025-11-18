class SuggestionFeedback < ApplicationRecord
  belongs_to :daily_log

  validates :suggestion_key, presence: true
  validates :helpfulness, inclusion: { in: [ true, false ] }
  validates :suggestion_key, uniqueness: { scope: :daily_log_id }
end
