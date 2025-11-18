# frozen_string_literal: true

module Weather
  class WeatherSnapshotService
    def self.update_for_prefecture(prefecture, date = Date.current)
      new(prefecture, date).update_snapshot
    end

    def self.update_all_prefectures(date = Date.current)
      Prefecture.find_each do |prefecture|
        update_for_prefecture(prefecture, date)
      rescue => e
        Rails.logger.error "Failed to update WeatherSnapshot for prefecture #{prefecture.id}: #{e.message}"
      end
    end

    def initialize(prefecture, date)
      @prefecture = prefecture
      @date = date
    end

    def update_snapshot
      metrics = calculate_metrics
      return nil if metrics.empty?

      WeatherSnapshot.find_or_initialize_by(
        prefecture: @prefecture,
        date: @date
      ).update!(metrics: metrics)
    end

    private

    def calculate_metrics
      metrics = {}

      # 当日の気象データを取得（9時頃のデータ）
      today_data = fetch_weather_data_for_date(@date)
      return metrics unless today_data

      # 湿度の平均値（当日の値を使用）
      metrics["humidity_avg"] = today_data[:humidity_pct] if today_data[:humidity_pct]

      # 前日のデータを取得（24時間変化の計算用）
      yesterday_data = fetch_weather_data_for_date(@date - 1.day)

      # 24時間前の気圧変化
      if today_data[:pressure_hpa] && yesterday_data&.dig(:pressure_hpa)
        metrics["pressure_drop_24h"] = (today_data[:pressure_hpa] - yesterday_data[:pressure_hpa]).round(1)
      end

      # 6時間前のデータを取得（6時間変化の計算用）
      # 当日9時から6時間前 = 当日3時
      six_hours_ago_hour = 3
      six_hours_ago_data = fetch_weather_data_for_hour(@date, six_hours_ago_hour)

      # 6時間前の気圧変化
      if today_data[:pressure_hpa] && six_hours_ago_data&.dig(:pressure_hpa)
        metrics["pressure_drop_6h"] = (today_data[:pressure_hpa] - six_hours_ago_data[:pressure_hpa]).round(1)
      end

      # 6時間前の気温変化
      if today_data[:temperature_c] && six_hours_ago_data&.dig(:temperature_c)
        metrics["temperature_drop_6h"] = (today_data[:temperature_c] - six_hours_ago_data[:temperature_c]).round(1)
      end

      # 12時間前のデータを取得（12時間変化の計算用）
      # 当日9時から12時間前 = 前日21時
      twelve_hours_ago_date = @date - 1.day
      twelve_hours_ago_hour = 21
      twelve_hours_ago_data = fetch_weather_data_for_hour(twelve_hours_ago_date, twelve_hours_ago_hour)

      # 12時間前の気温変化
      if today_data[:temperature_c] && twelve_hours_ago_data&.dig(:temperature_c)
        metrics["temperature_drop_12h"] = (today_data[:temperature_c] - twelve_hours_ago_data[:temperature_c]).round(1)
      end

      metrics
    end

    def fetch_weather_data_for_date(date, hour: 9)
      service = WeatherDataService.new(@prefecture, date, hour: hour)
      service.fetch_weather_data
    rescue => e
      Rails.logger.error "Failed to fetch weather data for date #{date}, hour #{hour}: #{e.message}"
      nil
    end

    def fetch_weather_data_for_hour(date, hour)
      # 指定日付・指定時刻のデータを取得
      service = WeatherDataService.new(@prefecture, date, hour: hour)
      data = service.fetch_weather_data

      return data if data && data[:observed_at]

      nil
    rescue => e
      Rails.logger.error "Failed to fetch weather data for date #{date}, hour #{hour}: #{e.message}"
      nil
    end
  end
end
