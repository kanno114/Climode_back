class UserTrigger < ApplicationRecord
  belongs_to :user
  belongs_to :trigger

  validates :user_id, uniqueness: { scope: :trigger_id }
  validate :trigger_must_be_active

  private

  def trigger_must_be_active
    return if trigger.nil? || trigger.is_active?

    errors.add(:trigger, "is not active")
  end
end
