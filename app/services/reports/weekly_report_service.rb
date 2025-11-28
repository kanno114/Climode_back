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
      analysis_service = WeeklyAnalysisService.new(@user, @week_start, @week_end)
      correlation_analyzer = CorrelationAnalyzer.new(daily_logs, weather_snapshots)

      {
        range: {
          start: @week_start.to_s,
          end: @week_end.to_s
        },
        signals: aggregate_signals,
        daily: aggregate_daily_logs,
        feedback: aggregate_feedback,
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

    def aggregate_signals
      signals = SignalEvent.for_user(@user)
                           .where("DATE(evaluated_at) >= ? AND DATE(evaluated_at) <= ?", @week_start, @week_end)

      total = signals.count

      # トリガー別集計
      by_trigger = signals.group(:trigger_key, :level)
                         .count
                         .group_by { |(trigger_key, _), _| trigger_key }
                         .map do |trigger_key, counts|
        level_counts = counts.each_with_object({ "strong" => 0, "attention" => 0, "warning" => 0 }) do |((_, level), count), acc|
          acc[level] = count if acc.key?(level)
        end

        {
          trigger_key: trigger_key,
          count: counts.sum { |_, count| count },
          strong: level_counts["strong"],
          attention: level_counts["attention"],
          warning: level_counts["warning"]
        }
      end

      # 日別集計
      by_day = signals.group("DATE(evaluated_at)")
                     .count
                     .map { |date, count| { date: date.to_s, count: count } }
                     .sort_by { |item| item[:date] }

      {
        total: total,
        by_trigger: by_trigger,
        by_day: by_day
      }
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

    def generate_insight(daily_logs, correlation_analyzer)
      signals = SignalEvent.for_user(@user)
                          .where("DATE(evaluated_at) >= ? AND DATE(evaluated_at) <= ?", @week_start, @week_end)

      return "今週は記録が少ないようです。日々の体調を記録すると、より詳しい振り返りができます。" if signals.empty? && daily_logs.empty?

      messages = []

      # シグナル情報
      if signals.any?
      trigger_counts = signals.group(:trigger_key).count
      top_trigger = trigger_counts.max_by { |_, count| count }

        if top_trigger
      trigger_key = top_trigger[0]
      count = top_trigger[1]
      trigger_label = Trigger.find_by(key: trigger_key)&.label || trigger_key.humanize
      strong_count = signals.where(trigger_key: trigger_key, level: "strong").count

      if strong_count > 0
        messages << "#{trigger_label}が#{count}回検出されました。"
        messages << "特に強いシグナルが#{strong_count}回ありました。"
      else
        messages << "#{trigger_label}が#{count}回検出されました。"
      end
        end
      end

      # 相関分析からのインサイト
      correlations = correlation_analyzer.call
      weather_corrs = correlations[:weather_health_correlations]

      if weather_corrs[:pressure_drop_24h_score] && weather_corrs[:pressure_drop_24h_score].abs > 0.5
        if weather_corrs[:pressure_drop_24h_score] < -0.5
          messages << "気圧低下と体調スコアに強い負の相関（#{weather_corrs[:pressure_drop_24h_score].round(2)}）が見られます。"
        end
      end

      # 条件別平均からのインサイト
      conditional = correlations[:conditional_averages]
      if conditional[:sleep_sufficient_score] && conditional[:sleep_insufficient_score]
        diff = conditional[:sleep_sufficient_score] - conditional[:sleep_insufficient_score]
        if diff > 5
          messages << "睡眠時間が7時間以上の日は、6時間未満の日より平均#{diff.round(1)}点高い体調スコアでした。"
        end
      end

      # 週内パターン
      patterns = analyze_weekly_patterns(daily_logs)
      if patterns[:week_half_comparison]
        comp = patterns[:week_half_comparison]
        if comp[:score_diff] && comp[:score_diff].abs > 5
          if comp[:score_diff] < 0
            messages << "週の後半に体調スコアが#{comp[:score_diff].abs.round(1)}点低下する傾向があります。"
          else
            messages << "週の後半に体調スコアが#{comp[:score_diff].round(1)}点向上する傾向があります。"
          end
        end
      end

      if messages.empty?
        messages << "今週の記録を続けることで、自分のリズムが見えてきます。"
      end

      messages.join(" ")
    end

    def analyze_weekly_patterns(daily_logs)
      return {} if daily_logs.empty?

      # 曜日別分析
      weekday_stats = {}
      (0..6).each do |wday|
        day_logs = daily_logs.select { |log| log.date.wday == wday }
        next if day_logs.empty?

        scores = day_logs.map(&:score).compact.map(&:to_f)
        sleep_hours = day_logs.map(&:sleep_hours).compact.map(&:to_f)
        moods = day_logs.map(&:mood).compact.map(&:to_f)

        weekday_stats[wday] = {
          avg_score: scores.any? ? (scores.sum / scores.size).round(2) : nil,
          avg_sleep_hours: sleep_hours.any? ? (sleep_hours.sum / sleep_hours.size).round(2) : nil,
          avg_mood: moods.any? ? (moods.sum / moods.size).round(2) : nil,
          count: day_logs.size
        }
      end

      # 週の前半vs後半
      first_half = daily_logs.select { |log| log.date.wday.between?(0, 2) } # 月〜水
      second_half = daily_logs.select { |log| log.date.wday.between?(3, 6) } # 木〜日

      first_half_scores = first_half.map(&:score).compact.map(&:to_f)
      second_half_scores = second_half.map(&:score).compact.map(&:to_f)

      week_half_comparison = nil
      if first_half_scores.any? && second_half_scores.any?
        first_avg = first_half_scores.sum / first_half_scores.size
        second_avg = second_half_scores.sum / second_half_scores.size
        week_half_comparison = {
          first_half_avg: first_avg.round(2),
          second_half_avg: second_avg.round(2),
          score_diff: (second_avg - first_avg).round(2)
        }
      end

      {
        weekday_stats: weekday_stats,
        week_half_comparison: week_half_comparison
      }
    end
  end
end
