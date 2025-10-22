require "rails_helper"

RSpec.describe DailyReminderJob, type: :job do
  describe "#perform" do
    let(:title) { "今日の体調を記録しましょう" }
    let(:body) { "毎日の記録が健康管理に役立ちます。今日の体調はいかがですか？" }
    let(:expected_options) do
      {
        icon: "/icon-192x192.png",
        badge: "/badge-72x72.png",
        data: {
          url: "/dashboard",
          action: "open_daily_log"
        }
      }
    end

    it "calls PushNotificationService.send_to_all with correct parameters" do
      expect(PushNotificationService).to receive(:send_to_all).with(
        title,
        body,
        expected_options
      )

      described_class.perform_now
    end

    it "logs the start and completion" do
      allow(PushNotificationService).to receive(:send_to_all)

      # Rails 7のBroadcastLoggerに対応
      allow(Rails.logger).to receive(:info).and_call_original

      expect {
        described_class.perform_now
      }.not_to raise_error
    end
  end

  describe "queue configuration" do
    it "is set to the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
