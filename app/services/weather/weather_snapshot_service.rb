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
      rescue Net::OpenTimeout => e
        Rails.logger.error "[Weather] Connection timeout updating snapshot for prefecture #{prefecture.id}: #{e.message}"
      rescue Net::ReadTimeout => e
        Rails.logger.error "[Weather] Read timeout updating snapshot for prefecture #{prefecture.id}: #{e.message}"
      rescue => e
        Rails.logger.error "[Weather] Failed to update snapshot for prefecture #{prefecture.id}: #{e.class} - #{e.message}"
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
      series = Weather::WeatherDataService.new(@prefecture, @date).fetch_forecast_series(
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

      # 当日の最低気温（ヒートショック等のルール用）
      min_temp = series
        .select { |p| p[:time].to_date == @date && p[:temperature_c].present? }
        .map { |p| p[:temperature_c].to_f }
      metrics["min_temperature_c"] = min_temp.min.round(1) if min_temp.any?

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

      # 起床時間帯（7:30〜22:00 相当）における気圧変動メトリクス
      awake_metrics = calculate_awake_hours_pressure_metrics(series, @date)
      metrics.merge!(awake_metrics) if awake_metrics.present?

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

    # 起床時間帯（概ね 7:30〜22:00）における気圧差メトリクスを計算する
    #
    # - max_pressure_drop_1h_awake: 1時間あたりの気圧低下の最大値（最も急激な低下、負の値）
    # - low_pressure_duration_1003h: 1003hPa 以下が連続して続いた最長時間（時間）
    # - low_pressure_duration_1007h: 1007hPa 以下が連続して続いた最長時間（時間）
    # - pressure_range_3h_awake: 3時間スライディングウィンドウでの気圧変化幅の最小値
    # - pressure_jitter_3h_awake: 3時間スライディングウィンドウでの気圧標準偏差の最大値
    def calculate_awake_hours_pressure_metrics(series, date)
      # 起床時間帯は 8:00〜22:00 として近似する（7:30〜22:00 の要件に対応）
      awake_points =
        series
          .select { |p| p[:time].to_date == date && p[:time].hour.between?(8, 22) }
          .sort_by { |p| p[:time] }

      return {} if awake_points.size < 2

      pressures = awake_points.map { |p| p[:pressure_hpa] }.compact
      return {} if pressures.size < 2

      metrics = {}

      # 1時間ごとの気圧変化（低下側の最大値=最も大きなマイナス値）
      max_drop = nil
      awake_points.each_cons(2) do |prev, cur|
        next unless prev[:pressure_hpa] && cur[:pressure_hpa]

        delta = (cur[:pressure_hpa] - prev[:pressure_hpa]).round(1)
        max_drop = [ max_drop, delta ].compact.min
      end
      metrics["max_pressure_drop_1h_awake"] = max_drop if max_drop

      # 低気圧継続時間（1時間刻みの連続時間を時間単位で表現）
      metrics["low_pressure_duration_1003h"] = max_consecutive_hours(awake_points, 1003.0)
      metrics["low_pressure_duration_1007h"] = max_consecutive_hours(awake_points, 1007.0)

      # 3時間スライディングウィンドウでの変化幅・標準偏差
      if awake_points.size >= 3
        ranges = []
        jitters = []

        awake_points.each_cons(3) do |window|
          values = window.map { |p| p[:pressure_hpa] }.compact
          next if values.size < 3

          min_v = values.min
          max_v = values.max
          ranges << (max_v - min_v).round(2)

          mean = values.sum.to_f / values.size
          variance = values.sum { |v| (v - mean) ** 2 } / values.size
          jitters << Math.sqrt(variance).round(3)
        end

        metrics["pressure_range_3h_awake"] = ranges.min if ranges.any?
        metrics["pressure_jitter_3h_awake"] = jitters.max if jitters.any?
      end

      metrics
    end

    # 指定しきい値以下の気圧が連続した最長時間（時間単位）を返す
    def max_consecutive_hours(points, threshold_hpa)
      max_count = 0
      current_count = 0

      points.each do |p|
        if p[:pressure_hpa] && p[:pressure_hpa] <= threshold_hpa
          current_count += 1
          max_count = [ max_count, current_count ].max
        else
          current_count = 0
        end
      end

      max_count.to_f
    end
  end
end
