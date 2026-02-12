module Reports
  class WeeklyReportService
    def initialize(user, week_start = nil)
      @user = user
      @week_start = week_start || calculate_current_week_start
      @week_end = @week_start + 6.days
    end

    def call
      daily_logs = load_daily_logs
      weather_snapshots = load_weather_snapshots(daily_logs)
      analysis_service = Reports::WeeklyAnalysisService.new(@user, @week_start, @week_end)
      correlation_analyzer = Reports::CorrelationAnalyzer.new(daily_logs, weather_snapshots)

      {
        range: {
          start: @week_start.to_s,
          end: @week_end.to_s
        },
        daily: aggregate_daily_logs,
        feedback: aggregate_feedback,
        suggestions: aggregate_suggestions,
        insight: generate_insight(daily_logs, correlation_analyzer),
        statistics: analysis_service.call,
        correlations: correlation_analyzer.call,
        patterns: analyze_weekly_patterns(daily_logs)
      }
    end

    private

    def calculate_current_week_start
      Date.current.beginning_of_week(:monday)
    end

    def aggregate_daily_logs
      daily_logs = @user.daily_logs.where(date: @week_start..@week_end).order(:date)

      sleep_hours = daily_logs.where.not(sleep_hours: nil).pluck(:sleep_hours)
      moods = daily_logs.where.not(mood: nil).pluck(:mood)
      fatigue_levels = daily_logs.where.not(fatigue_level: nil).pluck(:fatigue_level)

      # 日別データ
      by_day = daily_logs.map do |log|
        {
          date: log.date.to_s,
          sleep_hours: log.sleep_hours,
          mood: log.mood,
          fatigue_level: log.fatigue_level
        }
      end

      {
        avg_sleep_hours: sleep_hours.any? ? (sleep_hours.sum.to_f / sleep_hours.size).round(1) : nil,
        avg_mood: moods.any? ? (moods.sum.to_f / moods.size).round(1) : nil,
        avg_fatigue_level: fatigue_levels.any? ? (fatigue_levels.sum.to_f / fatigue_levels.size).round(1) : nil,
        by_day: by_day
      }
    end

    def aggregate_feedback
      daily_logs = @user.daily_logs.where(date: @week_start..@week_end).order(:date)
      suggestion_feedbacks = SuggestionFeedback.joins(:daily_log)
                                               .where(daily_logs: { id: daily_logs.pluck(:id) })

      helpful_count = suggestion_feedbacks.where(helpfulness: true).count
      not_helpful_count = suggestion_feedbacks.where(helpfulness: false).count
      total_count = helpful_count + not_helpful_count

      helpfulness_rate = total_count > 0 ? ((helpful_count.to_f / total_count) * 100).round(1) : nil

      # セルフスコアの統計
      self_scores = daily_logs.map(&:self_score).compact
      avg_self_score = self_scores.any? ? (self_scores.sum.to_f / self_scores.size).round(2) : nil
      self_score_distribution = {
        1 => self_scores.count(1),
        2 => self_scores.count(2),
        3 => self_scores.count(3)
      }

      # 日別データ
      feedback_by_date = suggestion_feedbacks.group_by { |fb| fb.daily_log.date.to_s }
      by_day = daily_logs.map do |log|
        date_str = log.date.to_s
        feedback = feedback_by_date[date_str]&.first
        {
          date: date_str,
          has_feedback: feedback.present?,
          helpfulness: feedback&.helpfulness,
          self_score: log.self_score
        }
      end

      {
        helpfulness_rate: helpfulness_rate,
        helpfulness_count: {
          helpful: helpful_count,
          not_helpful: not_helpful_count
        },
        avg_self_score: avg_self_score,
        self_score_distribution: self_score_distribution,
        by_day: by_day
      }
    end

    def aggregate_suggestions
      daily_logs = @user.daily_logs.where(date: @week_start..@week_end).order(:date)
      return { by_day: [] } if daily_logs.empty?

      log_ids = daily_logs.pluck(:id)
      suggestions = DailyLogSuggestion.where(daily_log_id: log_ids)
                                     .order(:daily_log_id, :position, :id)

      return { by_day: [] } if suggestions.empty?

      feedbacks = SuggestionFeedback
        .where(daily_log_id: log_ids)
        .index_by { |fb| [ fb.daily_log_id, fb.suggestion_key ] }

      suggestions_by_log = suggestions.group_by(&:daily_log_id)
      logs_by_id = daily_logs.index_by(&:id)

      by_day = suggestions_by_log.map do |daily_log_id, day_suggestions|
        log = logs_by_id[daily_log_id]
        next nil unless log

        items = day_suggestions.sort_by { |s| [ s.position || 0, s.id ] }.map do |s|
          fb = feedbacks[[ daily_log_id, s.suggestion_key ]]
          {
            suggestion_key: s.suggestion_key,
            title: s.title,
            message: s.message,
            helpfulness: fb&.helpfulness,
            category: s.category,
            level: s.level,
            tags: s.tags || []
          }
        end

        {
          date: log.date.to_s,
          items: items
        }
      end.compact.sort_by { |d| d[:date] }

      { by_day: by_day }
    end

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

    def generate_insight(daily_logs, _correlation_analyzer)
      return "今週は記録が少ないようです。日々の体調を記録すると、より詳しい振り返りができます。" if daily_logs.empty?

      "今週の記録を続けることで、自分のリズムが見えてきます。"
    end

    def analyze_weekly_patterns(daily_logs)
      return {} if daily_logs.empty?

      weekday_stats = {}
      (0..6).each do |wday|
        day_logs = daily_logs.select { |log| log.date.wday == wday }
        next if day_logs.empty?

        sleep_hours = day_logs.map(&:sleep_hours).compact.map(&:to_f)
        moods = day_logs.map(&:mood).compact.map(&:to_f)

        weekday_stats[wday] = {
          avg_sleep_hours: sleep_hours.any? ? (sleep_hours.sum / sleep_hours.size).round(2) : nil,
          avg_mood: moods.any? ? (moods.sum / moods.size).round(2) : nil,
          count: day_logs.size
        }
      end

      {
        weekday_stats: weekday_stats,
        week_half_comparison: nil
      }
    end
  end
end
