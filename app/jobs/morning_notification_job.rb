# Job to send morning push notification at scheduled time
class MorningNotificationJob < ApplicationJob
  queue_as :default

  retry_on Net::OpenTimeout, Net::ReadTimeout, wait: :polynomially_longer, attempts: 3

  def perform
    Rails.logger.info "Starting morning notification job..."

    title = "今日の行動提案"
    body = "今日の行動のヒントを確認しましょう"
    options = {
      icon: "/icon-192x192.png",
      badge: "/badge-72x72.png",
      data: { url: "/dashboard" }
    }

    PushNotificationService.send_to_all(title, body, options)

    Rails.logger.info "Morning notification job completed."
  rescue => e
    Sentry.capture_exception(e)
    Rails.logger.error "[MorningNotificationJob] #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace&.first(10)&.join("\n")
    raise
  end
end
