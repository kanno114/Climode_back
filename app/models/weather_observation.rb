class WeatherObservation < ApplicationRecord
  belongs_to :daily_log

  validates :observed_at, presence: true
  validates :temperature_c, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 60 }, allow_nil: true
  validates :humidity_pct, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :pressure_hpa, numericality: { greater_than_or_equal_to: 800, less_than_or_equal_to: 1100 }, allow_nil: true
end
