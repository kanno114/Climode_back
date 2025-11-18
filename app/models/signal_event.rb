class SignalEvent < ApplicationRecord
  belongs_to :user

  CATEGORIES = %w[env body].freeze

  validates :trigger_key, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :level, presence: true
  validates :priority, presence: true, numericality: { only_integer: true }
  validates :evaluated_at, presence: true
  validate :unique_per_user_trigger_date

  private

  def unique_per_user_trigger_date
    return unless user_id && trigger_key && evaluated_at

    existing = SignalEvent.where(user_id: user_id, trigger_key: trigger_key)
                          .where("DATE(evaluated_at) = ?", evaluated_at.to_date)
                          .where.not(id: id)

    if existing.exists?
      errors.add(:base, "already has a signal event for this trigger on this date")
    end
  end

  scope :for_user, ->(user) { where(user: user) }
  scope :for_date, ->(date) { where(evaluated_at: date.beginning_of_day..date.end_of_day) }
  scope :for_category, ->(category) { where(category: category) }
  scope :today, -> { for_date(Date.current) }
  scope :ordered_by_priority, -> { order(priority: :desc) }
end
