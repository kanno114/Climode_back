class SignalFeedback < ApplicationRecord
  belongs_to :daily_log

  validates :trigger_key, presence: true
  validates :match, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
end
