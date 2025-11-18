# Job to send morning signal notifications to users
class MorningSignalNotificationJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting morning signal notification job..."

    success_count = 0
    error_count = 0

    User.find_each do |user|
      next unless user.push_subscriptions.exists?

      signals = SignalEvent.for_user(user).today.ordered_by_priority
      next if signals.empty?

      top = signals.limit(3)
      title = "今日のシグナル：#{top.first.trigger_key_label}"
      body = top.map { |s| "#{s.trigger_key_label}（#{s.level_jp}）" }.join("・")

      begin
        PushNotificationService.send_to_user(
          user,
          title,
          body,
          icon: "/icon-192x192.png",
          data: { url: "/dashboard" }
        )
        success_count += 1
      rescue StandardError => e
        Rails.logger.error "Failed to send notification to user #{user.id}: #{e.message}"
        error_count += 1
      end
    end

    Rails.logger.info "Morning signal notification job completed. Success: #{success_count}, Errors: #{error_count}"
  end
end
