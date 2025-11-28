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
        weather_health_correlations: analyze_weather_health_correlations,
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
          score: log.score&.to_f,
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

    def analyze_weather_health_correlations
      {
        pressure_score: calculate_correlation(:pressure_hpa, :score),
        pressure_drop_24h_score: calculate_correlation(:pressure_drop_24h, :score),
        pressure_drop_6h_score: calculate_correlation(:pressure_drop_6h, :score),
        humidity_score: calculate_correlation(:humidity_pct, :score),
        temperature_score: calculate_correlation(:temperature_c, :score)
      }
    end

    def analyze_health_health_correlations
      {
        sleep_score: calculate_correlation(:sleep_hours, :score),
        mood_fatigue: calculate_correlation(:mood, :fatigue_level),
        sleep_mood: calculate_correlation(:sleep_hours, :mood)
      }
    end

    def calculate_conditional_averages
      {
        pressure_drop_low_score: calculate_conditional_average(
          ->(p) { p[:pressure_drop_24h] && p[:pressure_drop_24h] < -10 },
          :score
        ),
        pressure_drop_high_score: calculate_conditional_average(
          ->(p) { p[:pressure_drop_24h] && p[:pressure_drop_24h] > 0 },
          :score
        ),
        high_humidity_score: calculate_conditional_average(
          ->(p) { p[:humidity_pct] && p[:humidity_pct] > 70 },
          :score
        ),
        low_humidity_score: calculate_conditional_average(
          ->(p) { p[:humidity_pct] && p[:humidity_pct] < 40 },
          :score
        ),
        rapid_pressure_drop_score: calculate_conditional_average(
          ->(p) { p[:pressure_drop_6h] && p[:pressure_drop_6h] < -5 },
          :score
        ),
        rapid_pressure_rise_score: calculate_conditional_average(
          ->(p) { p[:pressure_drop_6h] && p[:pressure_drop_6h] > 5 },
          :score
        ),
        sleep_insufficient_score: calculate_conditional_average(
          ->(p) { p[:sleep_hours] && p[:sleep_hours] < 6 },
          :score
        ),
        sleep_sufficient_score: calculate_conditional_average(
          ->(p) { p[:sleep_hours] && p[:sleep_hours] >= 7 },
          :score
        ),
        low_mood_fatigue: calculate_conditional_average(
          ->(p) { p[:mood] && p[:mood] <= 2 },
          :fatigue_level
        )
      }
    end

    def analyze_signal_health_relationship
      return { with_signals_avg: nil, without_signals_avg: nil, signal_count: 0 } if @daily_logs.empty?

      user = @daily_logs.first.user
      min_date = @daily_logs.map(&:date).min
      max_date = @daily_logs.map(&:date).max

      signal_dates = SignalEvent.for_user(user)
                                 .where("DATE(evaluated_at) >= ? AND DATE(evaluated_at) <= ?",
                                        min_date, max_date)
                                 .pluck("DATE(evaluated_at)")
                                 .map(&:to_date)
                                 .to_set

      with_signals = @daily_logs.select { |log| signal_dates.include?(log.date) }
                                 .map(&:score).compact.map(&:to_f)
      without_signals = @daily_logs.reject { |log| signal_dates.include?(log.date) }
                                    .map(&:score).compact.map(&:to_f)

      {
        with_signals_avg: with_signals.any? ? (with_signals.sum / with_signals.size).round(2) : nil,
        without_signals_avg: without_signals.any? ? (without_signals.sum / without_signals.size).round(2) : nil,
        signal_count: signal_dates.size
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
  end
end
