require "rails_helper"

RSpec.describe Reports::WeeklyReportService do
  let(:user) { create(:user) }
  let(:prefecture) { create(:prefecture, :tokyo) }
  let(:week_start) { Date.current.beginning_of_week(:monday) }
  let(:week_end) { week_start + 6.days }

  before do
    user.update!(prefecture: prefecture)
  end

  describe "#call" do
    context "データがない場合" do
      it "空のレポートを返す" do
        service = described_class.new(user)
        result = service.call

        expect(result[:range][:start]).to eq(week_start.to_s)
        expect(result[:range][:end]).to eq(week_end.to_s)
        expect(result[:signals][:total]).to eq(0)
        expect(result[:signals][:by_trigger]).to eq([])
        expect(result[:signals][:by_day]).to eq([])
        expect(result[:daily][:avg_sleep_hours]).to be_nil
        expect(result[:daily][:avg_mood]).to be_nil
        expect(result[:daily][:avg_fatigue_level]).to be_nil
        expect(result[:feedback][:helpfulness_rate]).to be_nil
        expect(result[:feedback][:helpfulness_count][:helpful]).to eq(0)
        expect(result[:feedback][:helpfulness_count][:not_helpful]).to eq(0)
        expect(result[:insight]).to be_present
      end
    end

    context "データがある場合" do
      let!(:trigger) { Trigger.find_or_create_by(key: "pressure_drop") { |t| t.label = "気圧低下"; t.category = "env"; t.version = 1 } }
      let!(:signal1) do
        create(:signal_event,
               user: user,
               trigger_key: "pressure_drop",
               level: "strong",
               evaluated_at: week_start + 1.day)
      end
      let!(:signal2) do
        create(:signal_event,
               user: user,
               trigger_key: "pressure_drop",
               level: "attention",
               evaluated_at: week_start + 2.days)
      end
      let!(:daily_log1) do
        create(:daily_log,
               user: user,
               prefecture: prefecture,
               date: week_start + 1.day,
               sleep_hours: 7.0,
               mood: 2,
               fatigue_level: 3)
      end
      let!(:daily_log2) do
        create(:daily_log,
               user: user,
               prefecture: prefecture,
               date: week_start + 2.days,
               sleep_hours: 6.5,
               mood: 1,
               fatigue_level: 4)
      end
      let!(:suggestion_feedback1) do
        create(:suggestion_feedback,
               daily_log: daily_log1,
               suggestion_key: "test_suggestion",
               helpfulness: true)
      end
      let!(:suggestion_feedback2) do
        create(:suggestion_feedback,
               daily_log: daily_log2,
               suggestion_key: "test_suggestion2",
               helpfulness: false)
      end

      it "週次レポートを返す" do
        service = described_class.new(user)
        result = service.call

        expect(result[:range][:start]).to eq(week_start.to_s)
        expect(result[:range][:end]).to eq(week_end.to_s)

        # シグナル集計
        expect(result[:signals][:total]).to eq(2)
        expect(result[:signals][:by_trigger].length).to eq(1)
        expect(result[:signals][:by_trigger][0][:trigger_key]).to eq("pressure_drop")
        expect(result[:signals][:by_trigger][0][:count]).to eq(2)
        expect(result[:signals][:by_trigger][0][:strong]).to eq(1)
        expect(result[:signals][:by_trigger][0][:attention]).to eq(1)
        expect(result[:signals][:by_day].length).to eq(2)

        # 自己申告集計
        expect(result[:daily][:avg_sleep_hours]).to eq(6.8)
        expect(result[:daily][:avg_mood]).to eq(1.5)
        expect(result[:daily][:avg_fatigue_level]).to eq(3.5)

        # フィードバック集計
        expect(result[:feedback][:helpfulness_rate]).to eq(50.0)
        expect(result[:feedback][:helpfulness_count][:helpful]).to eq(1)
        expect(result[:feedback][:helpfulness_count][:not_helpful]).to eq(1)

        # インサイト
        expect(result[:insight]).to be_present
      end

      it "指定した週の開始日でレポートを返す" do
        target_week_start = week_start - 7.days
        service = described_class.new(user, target_week_start)
        result = service.call

        expect(result[:range][:start]).to eq(target_week_start.to_s)
        expect(result[:range][:end]).to eq((target_week_start + 6.days).to_s)
        expect(result[:signals][:total]).to eq(0)
      end
    end
  end
end
