# frozen_string_literal: true

module Weather
  class WeatherSnapshotService
    def self.update_for_prefecture(prefecture, date = Date.current)
      new(prefecture, date).update_snapshot
    end

    # キャッシュミス時に Controller から取得した series で hourly_forecast のみ保存する
    def self.save_hourly_forecast(prefecture, date, series)
      return if series.blank?

      instance = new(prefecture, date)
      forecast_array = instance.send(:build_hourly_forecast_for_date, series, date)
      return if forecast_array.blank?

      snapshot = WeatherSnapshot.find_or_initialize_by(prefecture: prefecture, date: date)
      snapshot.metrics = (snapshot.metrics || {}).merge("hourly_forecast" => forecast_array)
      snapshot.save!
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

      # 48時間分を1回だけ取得（前日〜当日）
      series = WeatherDataService.new(@prefecture, @date).fetch_forecast_series(
        hours: 48,
        start_date: @date - 1.day,
        end_date: @date
      )
      return metrics if series.blank?

      # 8:00 基準で各時刻の点を抽出
      today_data = find_point_at(series, @date, 8)
      yesterday_data = find_point_at(series, @date - 1.day, 8)
      six_hours_ago_data = find_point_at(series, @date, 2)   # 当日8時から6時間前 = 当日2時
      twelve_hours_ago_data = find_point_at(series, @date - 1.day, 20) # 当日8時から12時間前 = 前日20時

      return metrics unless today_data

      # 生の天気データを保存（スコア計算・提案生成用）
      metrics["temperature_c"] = today_data[:temperature_c] if today_data[:temperature_c]
      metrics["humidity_pct"] = today_data[:humidity_pct] if today_data[:humidity_pct]
      metrics["pressure_hpa"] = today_data[:pressure_hpa] if today_data[:pressure_hpa]
      metrics["humidity_avg"] = today_data[:humidity_pct] if today_data[:humidity_pct]

      # 24時間前の気圧変化（当日8時 - 前日8時）
      if today_data[:pressure_hpa] && yesterday_data&.dig(:pressure_hpa)
        metrics["pressure_drop_24h"] = (today_data[:pressure_hpa] - yesterday_data[:pressure_hpa]).round(1)
      end

      # 6時間前の気圧・気温変化（当日8時 - 当日2時）
      if today_data[:pressure_hpa] && six_hours_ago_data&.dig(:pressure_hpa)
        metrics["pressure_drop_6h"] = (today_data[:pressure_hpa] - six_hours_ago_data[:pressure_hpa]).round(1)
      end
      if today_data[:temperature_c] && six_hours_ago_data&.dig(:temperature_c)
        metrics["temperature_drop_6h"] = (today_data[:temperature_c] - six_hours_ago_data[:temperature_c]).round(1)
      end

      # 12時間前の気温変化（当日8時 - 前日20時）
      if today_data[:temperature_c] && twelve_hours_ago_data&.dig(:temperature_c)
        metrics["temperature_drop_12h"] = (today_data[:temperature_c] - twelve_hours_ago_data[:temperature_c]).round(1)
      end

      # 当日24時間分を hourly_forecast に保存（JSON 化可能な形式）
      metrics["hourly_forecast"] = build_hourly_forecast_for_date(series, @date)

      metrics
    end

    # 時系列から指定日付・時刻の点を1件返す
    def find_point_at(series, date, hour)
      series.find { |p| p[:time].to_date == date && p[:time].hour == hour }
    end

    # 当日分の24時間を API レスポンスと同形式の配列で返す（time は ISO8601 文字列）
    def build_hourly_forecast_for_date(series, date)
      series
        .select { |p| p[:time].to_date == date }
        .sort_by { |p| p[:time] }
        .first(24)
        .map { |p|
          {
            "time" => p[:time].respond_to?(:iso8601) ? p[:time].iso8601 : p[:time].to_s,
            "temperature_c" => p[:temperature_c],
            "humidity_pct" => p[:humidity_pct],
            "pressure_hpa" => p[:pressure_hpa],
            "weather_code" => p[:weather_code]
          }
        }
    end
  end
end
