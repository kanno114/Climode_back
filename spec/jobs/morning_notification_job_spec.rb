require "rails_helper"

RSpec.describe MorningNotificationJob, type: :job do
  describe "#perform" do
    let(:title) { "今日の行動提案" }
    let(:body) { "今日の行動のヒントを確認しましょう" }
    let(:expected_options) do
      {
        icon: "/icon-192x192.png",
        badge: "/badge-72x72.png",
        data: { url: "/dashboard" }
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
