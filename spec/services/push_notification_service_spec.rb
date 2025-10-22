require "rails_helper"

RSpec.describe PushNotificationService do
  let(:user) { create(:user) }
  let!(:subscription) { create(:push_subscription, user: user) }

  before do
    # Mock environment variables
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("VAPID_SUBJECT").and_return("mailto:test@example.com")
    allow(ENV).to receive(:[]).with("VAPID_PUBLIC_KEY").and_return("test_public_key")
    allow(ENV).to receive(:[]).with("VAPID_PRIVATE_KEY").and_return("test_private_key")
  end

  describe ".send_to_user" do
    let(:title) { "Test Title" }
    let(:body) { "Test Body" }
    let(:options) { { icon: "/test-icon.png" } }

    context "when user has subscriptions" do
      it "sends notification to all user subscriptions" do
        expect(WebPush).to receive(:payload_send).once

        PushNotificationService.send_to_user(user, title, body, options)
      end
    end

    context "when user has no subscriptions" do
      let(:user_without_subscription) { create(:user) }

      it "does not send any notifications" do
        expect(WebPush).not_to receive(:payload_send)

        PushNotificationService.send_to_user(user_without_subscription, title, body, options)
      end
    end

    context "when subscription is invalid" do
      before do
        response_double = double("response", body: "Invalid subscription")
        allow(WebPush).to receive(:payload_send).and_raise(WebPush::InvalidSubscription.new(response_double, "test.host"))
      end

      it "removes the invalid subscription" do
        expect {
          PushNotificationService.send_to_user(user, title, body, options)
        }.to change(PushSubscription, :count).by(-1)
      end
    end

    context "when subscription is expired" do
      before do
        response_double = double("response", body: "Expired subscription")
        allow(WebPush).to receive(:payload_send).and_raise(WebPush::ExpiredSubscription.new(response_double, "test.host"))
      end

      it "removes the expired subscription" do
        expect {
          PushNotificationService.send_to_user(user, title, body, options)
        }.to change(PushSubscription, :count).by(-1)
      end
    end
  end

  describe ".send_to_all" do
    let(:title) { "Broadcast Title" }
    let(:body) { "Broadcast Body" }

    it "sends notifications to all users with subscriptions" do
      # 新しく3人のユーザーを作成
      users = create_list(:user, 3)
      users.each { |u| create(:push_subscription, user: u) }

      # すべてのサブスクリプション数を取得
      subscription_count = PushSubscription.count

      expect(WebPush).to receive(:payload_send).exactly(subscription_count).times

      PushNotificationService.send_to_all(title, body)
    end
  end

  describe ".send_notification" do
    let(:title) { "Notification Title" }
    let(:body) { "Notification Body" }
    let(:options) { { icon: "/icon.png", data: { url: "/test" } } }

    it "sends notification with correct parameters" do
      expect(WebPush).to receive(:payload_send).with(
        hash_including(
          message: kind_of(String),
          endpoint: subscription.endpoint,
          p256dh: subscription.p256dh_key,
          auth: subscription.auth_key,
          vapid: hash_including(
            subject: "mailto:test@example.com",
            public_key: "test_public_key",
            private_key: "test_private_key"
          )
        )
      )

      PushNotificationService.send_notification(subscription, title, body, options)
    end

    it "includes correct message structure" do
      allow(WebPush).to receive(:payload_send) do |params|
        message = JSON.parse(params[:message])
        expect(message["title"]).to eq(title)
        expect(message["body"]).to eq(body)
        expect(message["icon"]).to eq("/icon.png")
        expect(message["data"]["url"]).to eq("/test")
      end

      PushNotificationService.send_notification(subscription, title, body, options)
    end

    context "with default options" do
      it "uses default icon and badge" do
        allow(WebPush).to receive(:payload_send) do |params|
          message = JSON.parse(params[:message])
          expect(message["icon"]).to eq("/icon-192x192.png")
          expect(message["badge"]).to eq("/badge-72x72.png")
        end

        PushNotificationService.send_notification(subscription, title, body)
      end
    end

    context "when an error occurs" do
      before do
        allow(WebPush).to receive(:payload_send).and_raise(StandardError.new("Test error"))
      end

      it "logs the error and does not raise" do
        expect(Rails.logger).to receive(:error).with(/Failed to send push notification/)

        expect {
          PushNotificationService.send_notification(subscription, title, body)
        }.not_to raise_error
      end
    end
  end
end
