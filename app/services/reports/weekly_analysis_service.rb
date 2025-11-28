# frozen_string_literal: true

module Reports
  class WeeklyAnalysisService
    def initialize(user, week_start, week_end)
      @user = user
      @week_start = week_start
      @week_end = week_end
    end

    def call
      daily_logs = load_daily_logs
      weather_snapshots = load_weather_snapshots(daily_logs)

      {
        health_metrics: analyze_health_metrics(daily_logs),
        weather_metrics: analyze_weather_metrics(weather_snapshots),
        weekly_comparison: compare_with_previous_week(daily_logs)
      }
    end

    private

    def load_daily_logs
      @user.daily_logs
           .where(date: @week_start..@week_end)
           .includes(:prefecture)
           .order(:date)
    end

    def load_weather_snapshots(daily_logs)
      prefecture_ids = daily_logs.map(&:prefecture_id).uniq
      dates = (@week_start..@week_end).to_a

      WeatherSnapshot.where(prefecture_id: prefecture_ids, date: dates)
                     .index_by { |ws| [ ws.prefecture_id, ws.date ] }
    end

    def analyze_health_metrics(daily_logs)
      {
        sleep_hours: calculate_statistics(
          daily_logs.map(&:sleep_hours).compact.map(&:to_f)
        ),
        mood: calculate_statistics(
          daily_logs.map(&:mood).compact.map(&:to_f)
        ),
        fatigue_level: calculate_statistics(
          daily_logs.map(&:fatigue_level).compact.map(&:to_f)
        ),
        score: calculate_statistics(
          daily_logs.map(&:score).compact.map(&:to_f)
        )
      }
    end

    def analyze_weather_metrics(weather_snapshots)
      metrics_data = {
        temperature_c: [],
        humidity_pct: [],
        pressure_hpa: [],
        pressure_drop_6h: [],
        pressure_drop_24h: []
      }

      weather_snapshots.each_value do |snapshot|
        metrics = snapshot.metrics || {}
        metrics_data[:temperature_c] << metrics["temperature_c"] if metrics["temperature_c"]
        metrics_data[:humidity_pct] << metrics["humidity_pct"] if metrics["humidity_pct"]
        metrics_data[:pressure_hpa] << metrics["pressure_hpa"] if metrics["pressure_hpa"]
        metrics_data[:pressure_drop_6h] << metrics["pressure_drop_6h"] if metrics["pressure_drop_6h"]
        metrics_data[:pressure_drop_24h] << metrics["pressure_drop_24h"] if metrics["pressure_drop_24h"]
      end

      {
        temperature_c: calculate_statistics(metrics_data[:temperature_c]),
        humidity_pct: calculate_statistics(metrics_data[:humidity_pct]),
        pressure_hpa: calculate_statistics(metrics_data[:pressure_hpa]),
        pressure_drop_6h: calculate_statistics(metrics_data[:pressure_drop_6h]),
        pressure_drop_24h: calculate_statistics(metrics_data[:pressure_drop_24h])
      }
    end

    def compare_with_previous_week(daily_logs)
      previous_week_start = @week_start - 7.days
      previous_week_end = @week_end - 7.days

      previous_logs = @user.daily_logs
                           .where(date: previous_week_start..previous_week_end)

      current_scores = daily_logs.map(&:score).compact.map(&:to_f)
      previous_scores = previous_logs.map(&:score).compact.map(&:to_f)

      return nil if current_scores.empty? || previous_scores.empty?

      current_avg = current_scores.sum / current_scores.size
      previous_avg = previous_scores.sum / previous_scores.size

      {
        score_diff: (current_avg - previous_avg).round(1),
        score_change_rate: previous_avg > 0 ? ((current_avg - previous_avg) / previous_avg * 100).round(1) : nil,
        current_avg: current_avg.round(1),
        previous_avg: previous_avg.round(1)
      }
    end

    def calculate_statistics(values)
      return empty_statistics if values.empty?

      sorted = values.sort
      n = sorted.size
      mean = sorted.sum / n
      variance = sorted.sum { |x| (x - mean)**2 } / n
      std_dev = Math.sqrt(variance)
      cv = mean != 0 ? (std_dev / mean * 100).round(2) : nil

      {
        mean: mean.round(2),
        median: calculate_median(sorted),
        std_dev: std_dev.round(2),
        min: sorted.first.round(2),
        max: sorted.last.round(2),
        q1: calculate_quartile(sorted, 0.25),
        q2: calculate_quartile(sorted, 0.5),
        q3: calculate_quartile(sorted, 0.75),
        coefficient_of_variation: cv
      }
    end

    def calculate_median(sorted_values)
      n = sorted_values.size
      if n.odd?
        sorted_values[n / 2].round(2)
      else
        ((sorted_values[n / 2 - 1] + sorted_values[n / 2]) / 2.0).round(2)
      end
    end

    def calculate_quartile(sorted_values, percentile)
      n = sorted_values.size
      return nil if n < 2

      index = (n - 1) * percentile
      lower = index.floor
      upper = index.ceil

      if lower == upper
        sorted_values[lower].round(2)
      else
        ((sorted_values[lower] + sorted_values[upper]) / 2.0).round(2)
      end
    end

    def empty_statistics
      {
        mean: nil,
        median: nil,
        std_dev: nil,
        min: nil,
        max: nil,
        q1: nil,
        q2: nil,
        q3: nil,
        coefficient_of_variation: nil
      }
    end
  end
end
