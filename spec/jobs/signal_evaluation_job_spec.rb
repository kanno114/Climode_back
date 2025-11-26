require "rails_helper"

RSpec.describe SignalEvaluationJob, type: :job do
  describe "#perform" do
    let(:date) { Date.current }
    let!(:prefecture) { create(:prefecture) }
    let!(:user) { create(:user, prefecture: prefecture) }
    let!(:trigger) { Trigger.find_by(key: "pressure_drop") || create(:trigger, key: "pressure_drop", category: "env", is_active: true) }
    let!(:user_trigger) { create(:user_trigger, user: user, trigger: trigger) }

    before do
      allow(Weather::WeatherSnapshotService).to receive(:update_all_prefectures)
    end

    it "WeatherSnapshotを更新する" do
      expect(Weather::WeatherSnapshotService).to receive(:update_all_prefectures).with(date)
      described_class.perform_now(date)
    end

    it "env系トリガーを評価する" do
      allow(Weather::WeatherSnapshotService).to receive(:update_all_prefectures)

      # WeatherSnapshotを作成（env系トリガー評価に必要）
      create(:weather_snapshot, prefecture: prefecture, date: date, metrics: {
        "pressure_drop_6h" => -7.0
      })

      # シグナルが作成されることを確認
      expect {
        described_class.perform_now(date)
      }.to change(SignalEvent, :count).by_at_least(1)
    end

    it "body系トリガーは評価しない" do
      body_trigger = Trigger.find_by(key: "sleep_shortage") || create(:trigger, key: "sleep_shortage", category: "body", is_active: true)
      create(:user_trigger, user: user, trigger: body_trigger)

      allow(Weather::WeatherSnapshotService).to receive(:update_all_prefectures)

      # WeatherSnapshotを作成（env系トリガー評価に必要）
      create(:weather_snapshot, prefecture: prefecture, date: date, metrics: {
        "pressure_drop_6h" => -7.0
      })

      # env系トリガーのみが増えており、body系は増えないことを確認
      env_count_before = SignalEvent.where(trigger_key: trigger.key).count
      body_count_before = SignalEvent.where(trigger_key: body_trigger.key).count

      described_class.perform_now(date)

      expect(SignalEvent.where(trigger_key: trigger.key).count).to be > env_count_before
      expect(SignalEvent.where(trigger_key: body_trigger.key).count).to eq(body_count_before)
    end

    it "都道府県が設定されていないユーザーはスキップする" do
      user_without_prefecture = create(:user, prefecture: nil)
      create(:user_trigger, user: user_without_prefecture, trigger: trigger)

      allow(Weather::WeatherSnapshotService).to receive(:update_all_prefectures)

      # WeatherSnapshotを作成（env系トリガー評価に必要）
      create(:weather_snapshot, prefecture: prefecture, date: date, metrics: {
        "pressure_drop_6h" => -7.0
      })

      # 都道府県があるuserのトリガーは評価されるが、都道府県がないuser_without_prefectureのトリガーは評価されない
      user_count_before = SignalEvent.where(user: user, trigger_key: trigger.key).count
      user_without_pref_count_before = SignalEvent.where(user: user_without_prefecture, trigger_key: trigger.key).count

      described_class.perform_now(date)

      expect(SignalEvent.where(user: user, trigger_key: trigger.key).count).to eq(user_count_before + 1)
      expect(SignalEvent.where(user: user_without_prefecture, trigger_key: trigger.key).count).to eq(user_without_pref_count_before)
    end
  end

  describe "queue configuration" do
    it "is set to the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
