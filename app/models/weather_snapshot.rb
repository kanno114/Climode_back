class WeatherSnapshot < ApplicationRecord
  belongs_to :prefecture

  validates :date, presence: true
  validates :prefecture_id, uniqueness: { scope: :date }

  scope :for_date, ->(date) { where(date: date) }
  scope :for_prefecture, ->(prefecture) { where(prefecture: prefecture) }
end
