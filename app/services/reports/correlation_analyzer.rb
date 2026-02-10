# frozen_string_literal: true

module Reports
  class CorrelationAnalyzer
    def initialize(daily_logs, weather_snapshots)
      @daily_logs = daily_logs
      @weather_snapshots = weather_snapshots
      @data_pairs = build_data_pairs
    end

    def call
      {
        weather_health_correlations: {},
        health_health_correlations: analyze_health_health_correlations,
        conditional_averages: calculate_conditional_averages,
        signal_health_analysis: analyze_signal_health_relationship
      }
    end

    private

    def build_data_pairs
      pairs = []

      @daily_logs.each do |log|
        snapshot = @weather_snapshots[[ log.prefecture_id, log.date ]]
        next unless snapshot

        metrics = snapshot.metrics || {}
        pairs << {
          date: log.date,
          sleep_hours: log.sleep_hours&.to_f,
          mood: log.mood&.to_f,
          fatigue_level: log.fatigue_level&.to_f,
          temperature_c: metrics["temperature_c"]&.to_f,
          humidity_pct: metrics["humidity_pct"]&.to_f,
          pressure_hpa: metrics["pressure_hpa"]&.to_f,
          pressure_drop_6h: metrics["pressure_drop_6h"]&.to_f,
          pressure_drop_24h: metrics["pressure_drop_24h"]&.to_f
        }
      end

      pairs
    end

    def analyze_health_health_correlations
      {
        mood_fatigue: calculate_correlation(:mood, :fatigue_level),
        sleep_mood: calculate_correlation(:sleep_hours, :mood)
      }
    end

    def calculate_conditional_averages
      {
        low_mood_fatigue: calculate_conditional_average(
          ->(p) { p[:mood] && p[:mood] <= 2 },
          :fatigue_level
        )
      }
    end

    def calculate_correlation(var1_key, var2_key)
      pairs = @data_pairs.select { |p| p[var1_key] && p[var2_key] }
      return nil if pairs.size < 3

      values1 = pairs.map { |p| p[var1_key] }
      values2 = pairs.map { |p| p[var2_key] }

      pearson_correlation(values1, values2)
    end

    def pearson_correlation(x_values, y_values)
      n = x_values.size
      return nil if n < 2

      x_mean = x_values.sum / n
      y_mean = y_values.sum / n

      numerator = x_values.zip(y_values).sum { |x, y| (x - x_mean) * (y - y_mean) }
      x_variance = x_values.sum { |x| (x - x_mean)**2 }
      y_variance = y_values.sum { |y| (y - y_mean)**2 }

      denominator = Math.sqrt(x_variance * y_variance)
      return nil if denominator.zero?

      (numerator / denominator).round(3)
    end

    def calculate_conditional_average(condition, metric_key)
      matching_pairs = @data_pairs.select(&condition)
      return nil if matching_pairs.empty?

      values = matching_pairs.map { |p| p[metric_key] }.compact
      return nil if values.empty?

      (values.sum / values.size).round(2)
    end

    def analyze_signal_health_relationship
      {}
    end
  end
end
