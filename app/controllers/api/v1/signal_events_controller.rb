class Api::V1::SignalEventsController < ApplicationController
  include Authenticatable

  # GET /api/v1/signal_events/today
  def today
    date = Date.current
    signal_events = SignalEvent.for_user(current_user).for_date(date).ordered_by_priority

    # 未作成時はenvのみ即時評価して返す
    if signal_events.empty?
      signal_events = evaluate_env_signals_immediately(date)
    end

    render json: signal_events.as_json(
      only: [:id, :trigger_key, :category, :level, :priority, :evaluated_at, :meta]
    )
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
end

