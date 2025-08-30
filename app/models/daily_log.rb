class DailyLog < ApplicationRecord
  belongs_to :user
  belongs_to :prefecture
  has_one :weather_observation, dependent: :destroy
  has_many :daily_log_symptoms, dependent: :destroy
  has_many :symptoms, through: :daily_log_symptoms

  validates :date, presence: true
  validates :date, uniqueness: { scope: :user_id }
  validates :sleep_hours, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 24 }, allow_nil: true
  validates :mood, numericality: { greater_than_or_equal_to: -5, less_than_or_equal_to: 5 }, allow_nil: true
  validates :fatigue, numericality: { greater_than_or_equal_to: -5, less_than_or_equal_to: 5 }, allow_nil: true
  validates :score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :self_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
end
