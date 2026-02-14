# Job to send daily reminder notifications to users
class DailyReminderJob < ApplicationJob
  queue_as :default

  retry_on Net::OpenTimeout, Net::ReadTimeout, wait: :polynomially_longer, attempts: 3

  def perform
    Rails.logger.info "Starting daily reminder job..."

    title = "今日の体調を記録しましょう"
    body = "毎日の記録が健康管理に役立ちます。今日の体調はいかがですか？"
    options = {
      icon: "/icon-192x192.png",
      badge: "/badge-72x72.png",
      data: {
        url: "/dashboard",
        action: "open_daily_log"
      }
    }

    PushNotificationService.send_to_all(title, body, options)

    Rails.logger.info "Daily reminder job completed."
  rescue => e
    Rails.logger.error "[DailyReminderJob] #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace&.first(10)&.join("\n")
    raise
  end
end
