class DailyLog < ApplicationRecord
  belongs_to :user
  belongs_to :prefecture
  has_many :signal_feedbacks, dependent: :destroy
  has_many :suggestion_feedbacks, dependent: :destroy

  validates :date, presence: true
  validates :date, uniqueness: { scope: :user_id }
  validates :sleep_hours, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 24 }, allow_nil: true
  validates :mood, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }, allow_nil: true
  validates :fatigue, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }, allow_nil: true
  validates :self_score, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 3 }, allow_nil: true
  validates :helpfulness, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }, allow_nil: true
  validates :match_score, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }, allow_nil: true
  validates :fatigue_level, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }, allow_nil: true

  # 身体指標をハッシュ形式で返す（シグナル判定用）
  def body_metrics
    {
      sleep_hours: sleep_hours,
      mood: mood,
      fatigue: fatigue
    }.compact
  end
end
