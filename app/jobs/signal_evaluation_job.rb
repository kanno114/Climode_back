# Job to evaluate signal events for all users
class SignalEvaluationJob < ApplicationJob
  queue_as :default

  def perform(date = Date.current)
    Rails.logger.info "Starting signal evaluation job for #{date}..."

    # 1. 全都道府県のWeatherSnapshotを更新
    update_weather_snapshots(date)

    # 2. 全ユーザーの環境系トリガー（env）を判定
    evaluate_env_triggers(date)

    Rails.logger.info "Signal evaluation job completed."
  end

  private

  def update_weather_snapshots(date)
    Rails.logger.info "Updating weather snapshots for all prefectures..."
    Weather::WeatherSnapshotService.update_all_prefectures(date)
  end

  def evaluate_env_triggers(date)
    Rails.logger.info "Evaluating env triggers for all users..."

    User.find_each do |user|
      next unless user.prefecture # 都道府県が設定されていないユーザーはスキップ

      begin
        # env系トリガーのみを評価
        user_triggers = UserTrigger.where(user_id: user.id)
                                   .joins(:trigger)
                                   .where(triggers: { category: "env", is_active: true })
                                   .includes(:trigger)

        next if user_triggers.empty?

        # 各env系トリガーを評価
        user_triggers.each do |user_trigger|
          trigger = user_trigger.trigger
          result = Signal::EvaluationService.new(user, date).evaluate_trigger(trigger)

          if result
            Rails.logger.info "Created signal event for user #{user.id}, trigger #{trigger.key}, level #{result.level}"
          end
        end
      rescue => e
        Rails.logger.error "Failed to evaluate triggers for user #{user.id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
  end
end
