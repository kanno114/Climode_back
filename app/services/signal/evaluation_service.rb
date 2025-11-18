# frozen_string_literal: true

module Signal
  class EvaluationService
    def self.evaluate_for_user(user, date = Date.current)
      new(user, date).evaluate
    end

    def initialize(user, date)
      @user = user
      @date = date
    end

    def evaluate
      results = []

      # ユーザーの登録済みトリガーを取得
      user_triggers = UserTrigger.where(user_id: @user.id).includes(:trigger)

      user_triggers.each do |user_trigger|
        trigger = user_trigger.trigger
        next unless trigger.is_active

        result = evaluate_trigger(trigger)
        results << result if result
      end

      results
    end

    def evaluate_trigger(trigger)
      rule = trigger.rule
      return nil unless rule && rule["metric"] && rule["operator"] && rule["levels"]

      metric_key = rule["metric"]
      operator = rule["operator"]
      levels = rule["levels"].sort_by { |lv| lv["priority"] }.reverse

      # 観測値を取得
      observed = get_observed_value(trigger, metric_key)
      return nil if observed.nil?

      # レベル判定（優先度の高い順）
      matched = levels.find do |level|
        threshold = level["threshold"]
        compare_value(observed, threshold, operator)
      end

      return nil unless matched

      # SignalEventを作成または更新
      create_or_update_signal_event(trigger, matched, observed, metric_key, operator)
    end

    private

    def get_observed_value(trigger, metric_key)
      case trigger.category
      when "env"
        get_env_metric(metric_key)
      when "body"
        get_body_metric(metric_key)
      else
        nil
      end
    end

    def get_env_metric(metric_key)
      return nil unless @user.prefecture

      snapshot = WeatherSnapshot.find_by(
        prefecture: @user.prefecture,
        date: @date
      )

      return nil unless snapshot&.metrics

      snapshot.metrics[metric_key]
    end

    def get_body_metric(metric_key)
      daily_log = DailyLog.find_by(user: @user, date: @date)
      return nil unless daily_log

      body_metrics = daily_log.body_metrics
      body_metrics[metric_key.to_sym] || body_metrics[metric_key.to_s]
    end

    def compare_value(observed, threshold, operator)
      case operator
      when "lte"
        observed <= threshold
      when "gte"
        observed >= threshold
      when "lt"
        observed < threshold
      when "gt"
        observed > threshold
      else
        false
      end
    end

    def create_or_update_signal_event(trigger, matched_level, observed, metric_key, operator)
      evaluated_at = Time.current
      evaluated_date = evaluated_at.to_date

      # 当日の同一トリガーのイベントを検索
      signal_event = SignalEvent.where(user: @user, trigger_key: trigger.key)
                                .where("DATE(evaluated_at) = ?", evaluated_date)
                                .first_or_initialize

      signal_event.assign_attributes(
        category: trigger.category,
        level: matched_level["id"],
        priority: matched_level["priority"],
        evaluated_at: evaluated_at,
        meta: {
          observed: observed,
          threshold: matched_level["threshold"],
          metric: metric_key,
          operator: operator
        }
      )

      signal_event.save!
      signal_event
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to create SignalEvent: #{e.message}"
      nil
    end
  end
end
