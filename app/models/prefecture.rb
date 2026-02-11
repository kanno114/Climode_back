class Prefecture < ApplicationRecord
  has_many :users
  has_many :daily_logs
  has_many :suggestion_snapshots

  validates :code, presence: true, uniqueness: true
  validates :name_ja, presence: true
  validates :centroid_lat, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :centroid_lon, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
end
