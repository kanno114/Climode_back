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

  # 天気データ自動取得のコールバック
  after_create :fetch_weather_data
  after_update :fetch_weather_data, if: :prefecture_id_changed?

  private

  def fetch_weather_data
    return unless prefecture&.centroid_lat && prefecture&.centroid_lon

    begin
      weather_service = ::Weather::WeatherDataService.new(prefecture, date)
      weather_data = weather_service.fetch_weather_data

      # 既存の天気データがあれば更新、なければ作成
      if weather_observation
        weather_observation.update!(weather_data)
      else
        create_weather_observation!(weather_data)
      end
    rescue => e
      Rails.logger.error "Failed to fetch weather data for DailyLog #{id}: #{e.message}"
    end
  end
end
