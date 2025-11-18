require "rails_helper"

RSpec.describe SignalEvaluationJob, type: :job do
  describe "#perform" do
    let(:date) { Date.current }
    let!(:prefecture) { create(:prefecture) }
    let!(:user) { create(:user, prefecture: prefecture) }
    let!(:trigger) { create(:trigger, key: "pressure_drop", category: "env", is_active: true) }
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
      allow_any_instance_of(Signal::EvaluationService).to receive(:evaluate_trigger).and_return(true)

      expect_any_instance_of(Signal::EvaluationService).to receive(:evaluate_trigger).at_least(:once)
      described_class.perform_now(date)
    end

    it "body系トリガーは評価しない" do
      body_trigger = create(:trigger, key: "sleep_shortage", category: "body", is_active: true)
      create(:user_trigger, user: user, trigger: body_trigger)

      allow(Weather::WeatherSnapshotService).to receive(:update_all_prefectures)
      allow_any_instance_of(Signal::EvaluationService).to receive(:evaluate_trigger).and_return(true)

      # env系トリガーのみが評価されることを確認
      expect_any_instance_of(Signal::EvaluationService).to receive(:evaluate_trigger).with(trigger).once
      expect_any_instance_of(Signal::EvaluationService).not_to receive(:evaluate_trigger).with(body_trigger)
      described_class.perform_now(date)
    end

    it "都道府県が設定されていないユーザーはスキップする" do
      user_without_prefecture = create(:user, prefecture: nil)
      create(:user_trigger, user: user_without_prefecture, trigger: trigger)

      allow(Weather::WeatherSnapshotService).to receive(:update_all_prefectures)
      
      expect_any_instance_of(Signal::EvaluationService).not_to receive(:evaluate_trigger)
      described_class.perform_now(date)
    end
  end

  describe "queue configuration" do
    it "is set to the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end

