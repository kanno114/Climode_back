require "rails_helper"

RSpec.describe MorningSignalNotificationJob, type: :job do
  describe "#perform" do
    let(:user) { create(:user) }
    let(:user_without_signals) { create(:user) }
    let(:user_without_subscription) { create(:user) }
    let(:trigger) { find_or_create_trigger("pressure_drop", "気圧低下") }
    let(:trigger2) { find_or_create_trigger("humidity_high", "高湿度") }
    let(:trigger3) { find_or_create_trigger("temperature_drop", "気温低下") }

    before do
      # プッシュ通知登録済みユーザー
      create(:push_subscription, user: user)
      create(:push_subscription, user: user_without_signals)

      # 今日のシグナルを作成
      create(:signal_event, user: user, trigger_key: trigger.key, level: "warning", priority: 80, evaluated_at: Time.current)
      create(:signal_event, user: user, trigger_key: trigger2.key, level: "attention", priority: 60, evaluated_at: Time.current)
      create(:signal_event, user: user, trigger_key: trigger3.key, level: "strong", priority: 90, evaluated_at: Time.current)

      # プッシュ通知サービスをモック
      allow(PushNotificationService).to receive(:send_to_user)
    end

    it "シグナルがあるユーザーに通知が送信される" do
      expect(PushNotificationService).to receive(:send_to_user).with(
        user,
        anything,
        anything,
        hash_including(data: { url: "/dashboard" })
      )

      described_class.perform_now
    end

    it "シグナルがないユーザーはスキップされる" do
      expect(PushNotificationService).not_to receive(:send_to_user).with(
        user_without_signals,
        anything,
        anything,
        anything
      )

      described_class.perform_now
    end

    it "通知タイトルが正しい" do
      described_class.perform_now

      expect(PushNotificationService).to have_received(:send_to_user).with(
        user,
        "今日のシグナル：#{trigger3.label}", # 優先度が最も高い（90）トリガー
        anything,
        anything
      )
    end

    it "通知本文が優先度順で上位3件を含む" do
      described_class.perform_now

      # 優先度順: 気温低下(90) > 気圧低下(80) > 高湿度(60)
      expect(PushNotificationService).to have_received(:send_to_user).with(
        user,
        anything,
        "#{trigger3.label}（強）・#{trigger.label}（警戒）・#{trigger2.label}（注意）",
        anything
      )
    end

    it "通知のdata.urlが/dashboardである" do
      described_class.perform_now

      expect(PushNotificationService).to have_received(:send_to_user).with(
        user,
        anything,
        anything,
        hash_including(
          icon: "/icon-192x192.png",
          data: { url: "/dashboard" }
        )
      )
    end

    it "プッシュ通知未登録ユーザーには送信されない" do
      create(:signal_event, user: user_without_subscription, trigger_key: trigger.key, level: "warning", priority: 80, evaluated_at: Time.current)

      described_class.perform_now

      expect(PushNotificationService).not_to have_received(:send_to_user).with(
        user_without_subscription,
        anything,
        anything,
        anything
      )
    end

    it "ログ出力が正しい" do
      allow(Rails.logger).to receive(:info).and_call_original

      described_class.perform_now

      expect(Rails.logger).to have_received(:info).with("Starting morning signal notification job...")
      expect(Rails.logger).to have_received(:info).with(/Morning signal notification job completed\. Success: \d+, Errors: \d+/)
    end

    context "エラーハンドリング" do
      it "通知送信エラー時にログを出力し、処理を継続する" do
        allow(PushNotificationService).to receive(:send_to_user).and_raise(StandardError.new("Network error"))
        allow(Rails.logger).to receive(:error).and_call_original

        expect {
          described_class.perform_now
        }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(/Failed to send notification to user \d+: Network error/)
      end

      it "エラーが発生しても他のユーザーには通知が送信される" do
        user2 = create(:user)
        create(:push_subscription, user: user2)
        create(:signal_event, user: user2, trigger_key: trigger.key, level: "warning", priority: 80, evaluated_at: Time.current)

        allow(PushNotificationService).to receive(:send_to_user).with(user, anything, anything, anything).and_raise(StandardError.new("Network error"))

        described_class.perform_now

        expect(PushNotificationService).to have_received(:send_to_user).with(user2, anything, anything, anything)
      end
    end

    context "シグナルが3件未満の場合" do
      it "存在するシグナルのみを通知本文に含める" do
        # シグナルを1件のみに
        SignalEvent.where(user: user).where.not(trigger_key: trigger.key).destroy_all

        described_class.perform_now

        expect(PushNotificationService).to have_received(:send_to_user).with(
          user,
          "今日のシグナル：#{trigger.label}",
          "#{trigger.label}（警戒）",
          anything
        )
      end
    end
  end

  describe "queue configuration" do
    it "is set to the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end

  def find_or_create_trigger(key, label)
    Trigger.find_or_create_by!(key: key) do |t|
      t.label = label
      t.category = "env"
      t.is_active = true
      t.version = 1
      t.rule = {}
    end
  end
end
