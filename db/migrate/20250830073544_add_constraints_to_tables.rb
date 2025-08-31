class AddConstraintsToTables < ActiveRecord::Migration[7.2]
  def change
    # DailyLogs テーブルの制約
    add_check_constraint :daily_logs, "sleep_hours >= 0 AND sleep_hours <= 24", name: "check_sleep_hours_range"
    add_check_constraint :daily_logs, "mood >= -5 AND mood <= 5", name: "check_mood_range"
    add_check_constraint :daily_logs, "fatigue >= -5 AND fatigue <= 5", name: "check_fatigue_range"
    add_check_constraint :daily_logs, "score >= 0 AND score <= 100", name: "check_score_range"
    add_check_constraint :daily_logs, "self_score >= 0 AND self_score <= 100", name: "check_self_score_range"

    # WeatherObservations テーブルの制約
    add_check_constraint :weather_observations, "temperature_c >= -90 AND temperature_c <= 60", name: "check_temperature_range"
    add_check_constraint :weather_observations, "humidity_pct >= 0 AND humidity_pct <= 100", name: "check_humidity_range"
    add_check_constraint :weather_observations, "pressure_hpa >= 800 AND pressure_hpa <= 1100", name: "check_pressure_range"

    # Prefectures テーブルの制約
    add_check_constraint :prefectures, "centroid_lat >= -90 AND centroid_lat <= 90", name: "check_latitude_range"
    add_check_constraint :prefectures, "centroid_lon >= -180 AND centroid_lon <= 180", name: "check_longitude_range"
  end
end
