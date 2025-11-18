module Reports
  class WeeklyReportService
    def initialize(user, week_start = nil)
      @user = user
      @week_start = week_start || calculate_current_week_start
      @week_end = @week_start + 6.days
    end

    def call
      {
        range: {
          start: @week_start.to_s,
          end: @week_end.to_s
        },
        signals: aggregate_signals,
        daily: aggregate_daily_logs,
        feedback: aggregate_feedback,
        insight: generate_insight
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
      daily_logs = @user.daily_logs.where(date: @week_start..@week_end)

      sleep_hours = daily_logs.where.not(sleep_hours: nil).pluck(:sleep_hours)
      moods = daily_logs.where.not(mood: nil).pluck(:mood)
      fatigue_levels = daily_logs.where.not(fatigue_level: nil).pluck(:fatigue_level)

      {
        avg_sleep_hours: sleep_hours.any? ? (sleep_hours.sum.to_f / sleep_hours.size).round(1) : nil,
        avg_mood: moods.any? ? (moods.sum.to_f / moods.size).round(1) : nil,
        avg_fatigue_level: fatigue_levels.any? ? (fatigue_levels.sum.to_f / fatigue_levels.size).round(1) : nil
      }
    end

    def aggregate_feedback
      daily_logs = @user.daily_logs.where(date: @week_start..@week_end)
      suggestion_feedbacks = SuggestionFeedback.joins(:daily_log)
                                               .where(daily_logs: { id: daily_logs.pluck(:id) })

      helpful_count = suggestion_feedbacks.where(helpfulness: true).count
      not_helpful_count = suggestion_feedbacks.where(helpfulness: false).count
      total_count = helpful_count + not_helpful_count

      helpfulness_rate = total_count > 0 ? ((helpful_count.to_f / total_count) * 100).round(1) : nil

      {
        helpfulness_rate: helpfulness_rate,
        helpfulness_count: {
          helpful: helpful_count,
          not_helpful: not_helpful_count
        }
      }
    end

    def generate_insight
      signals = SignalEvent.for_user(@user)
                          .where("DATE(evaluated_at) >= ? AND DATE(evaluated_at) <= ?", @week_start, @week_end)

      return "今週は記録が少ないようです。日々の体調を記録すると、より詳しい振り返りができます。" if signals.empty?

      # 最も多いトリガーを取得
      trigger_counts = signals.group(:trigger_key).count
      top_trigger = trigger_counts.max_by { |_, count| count }

      return "今週は記録が少ないようです。" unless top_trigger

      trigger_key = top_trigger[0]
      count = top_trigger[1]
      trigger_label = Trigger.find_by(key: trigger_key)&.label || trigger_key.humanize

      # レベル別の傾向
      strong_count = signals.where(trigger_key: trigger_key, level: "strong").count
      attention_count = signals.where(trigger_key: trigger_key, level: "attention").count

      messages = []

      if strong_count > 0
        messages << "#{trigger_label}が#{count}回検出されました。"
        messages << "特に強いシグナルが#{strong_count}回ありました。"
        messages << "休息と水分補給を意識できると安心です。"
      elsif attention_count > 0
        messages << "#{trigger_label}が#{count}回検出されました。"
        messages << "体調の変化に気をつけながら、無理のないペースで過ごせると良いですね。"
      else
        messages << "#{trigger_label}が#{count}回検出されました。"
        messages << "日々の記録を続けることで、自分のリズムが見えてきます。"
      end

      messages.join(" ")
    end
  end
end
