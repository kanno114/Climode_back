# Service Object for sending Web Push notifications
class PushNotificationService
  # Send notification to a specific user
  # @param user [User] The user to send notification to
  # @param title [String] Notification title
  # @param body [String] Notification body
  # @param options [Hash] Additional notification options (icon, badge, data, etc.)
  def self.send_to_user(user, title, body, options = {})
    return unless user.push_subscriptions.any?

    user.push_subscriptions.each do |subscription|
      send_notification(subscription, title, body, options)
    end
  end

  # Send notification to all users
  # @param title [String] Notification title
  # @param body [String] Notification body
  # @param options [Hash] Additional notification options
  def self.send_to_all(title, body, options = {})
    User.includes(:push_subscriptions).find_each do |user|
      send_to_user(user, title, body, options)
    end
  end

  # Send notification to a single subscription
  # @param subscription [PushSubscription] The subscription to send to
  # @param title [String] Notification title
  # @param body [String] Notification body
  # @param options [Hash] Additional notification options
  def self.send_notification(subscription, title, body, options = {})
    message = {
      title: title,
      body: body,
      icon: options[:icon] || "/icon-192x192.png",
      badge: options[:badge] || "/badge-72x72.png",
      data: options[:data] || {}
    }.to_json

    Webpush.payload_send(
      message: message,
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh_key,
      auth: subscription.auth_key,
      vapid: {
        subject: ENV["VAPID_SUBJECT"] || "mailto:admin@climode.example.com",
        public_key: ENV["VAPID_PUBLIC_KEY"],
        private_key: ENV["VAPID_PRIVATE_KEY"]
      }
    )
  rescue Webpush::InvalidSubscription, Webpush::ExpiredSubscription => e
    # Remove invalid or expired subscriptions
    Rails.logger.info "Removing invalid subscription: #{e.message}"
    subscription.destroy
  rescue StandardError => e
    Rails.logger.error "Failed to send push notification: #{e.message}"
  end
end


