class SignalFeedback < ApplicationRecord
  belongs_to :daily_log

  validates :trigger_key, presence: true
  validates :match, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validate :trigger_key_exists

  private

  def trigger_key_exists
    return if trigger_key.blank?

    unless Trigger.exists?(key: trigger_key)
      errors.add(:trigger_key, "does not exist in triggers table")
    end
  end
end
