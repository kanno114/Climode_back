class Api::V1::SignalEventsController < ApplicationController
  include Authenticatable

  # GET /api/v1/signal_events
  # クエリパラメータ:
  #   category: "env" または "body" でフィルタリング（省略時は全て）
  #   date: 日付（YYYY-MM-DD形式、省略時は今日）
  def index
    date = params[:date] ? Date.parse(params[:date]) : Date.current
    signal_events = SignalEvent.for_user(current_user).for_date(date).ordered_by_priority

    # 未作成時はenvとbodyを即時評価して返す
    if signal_events.empty?
      env_signal_ids = evaluate_env_signals_immediately(date).pluck(:id)
      body_signal_ids = evaluate_body_signals_immediately(date).pluck(:id)
      all_signal_ids = env_signal_ids + body_signal_ids

      if all_signal_ids.any?
        signal_events = SignalEvent.where(id: all_signal_ids)
      else
        signal_events = SignalEvent.none
      end
    end

    # カテゴリでフィルタリング
    if params[:category].present?
      signal_events = signal_events.for_category(params[:category])
    end

    render json: signal_events.map { |event|
      event.as_json(
      only: [ :id, :trigger_key, :category, :level, :priority, :evaluated_at, :meta ]
      ).merge(trigger_key_label: event.trigger_key_label)
    }
  end

  private

  def evaluate_env_signals_immediately(date)
    # WeatherSnapshotを更新
    if current_user.prefecture
      Weather::WeatherSnapshotService.update_for_prefecture(current_user.prefecture, date)
    end

    # env系トリガーのみを即時評価
    results = []
    user_triggers = UserTrigger.where(user_id: current_user.id)
                               .joins(:trigger)
                               .where(triggers: { category: "env", is_active: true })
                               .includes(:trigger)

    user_triggers.each do |user_trigger|
      trigger = user_trigger.trigger
      result = Signal::EvaluationService.new(current_user, date).evaluate_trigger(trigger)
      results << result if result
    end

    SignalEvent.where(id: results.map(&:id))
  end

  def evaluate_body_signals_immediately(date)
    # DailyLogが存在する場合のみ評価
    daily_log = DailyLog.find_by(user: current_user, date: date)
    return SignalEvent.none unless daily_log

    # body系トリガーのみを即時評価
    results = []
    user_triggers = UserTrigger.where(user_id: current_user.id)
                               .joins(:trigger)
                               .where(triggers: { category: "body", is_active: true })
                               .includes(:trigger)

    user_triggers.each do |user_trigger|
      trigger = user_trigger.trigger
      result = Signal::EvaluationService.new(current_user, date).evaluate_trigger(trigger)
      results << result if result
    end

    SignalEvent.where(id: results.map(&:id))
  end
end
