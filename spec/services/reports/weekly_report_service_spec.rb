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
        expect(result[:daily][:avg_sleep_hours]).to be_nil
        expect(result[:daily][:avg_mood]).to be_nil
        expect(result[:daily][:avg_fatigue_level]).to be_nil
        expect(result[:feedback][:helpfulness_rate]).to be_nil
        expect(result[:feedback][:helpfulness_count][:helpful]).to eq(0)
        expect(result[:feedback][:helpfulness_count][:not_helpful]).to eq(0)
        expect(result[:suggestions][:by_day]).to eq([])
        expect(result[:insight]).to be_present
      end
    end

    context "データがある場合" do
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
        rule = SuggestionRule.find_by!(key: "test_suggestion")
        create(:suggestion_feedback,
               daily_log: daily_log1,
               suggestion_rule: rule,
               helpfulness: true)
      end
      let!(:suggestion_feedback2) do
        rule = SuggestionRule.find_by!(key: "test_suggestion2")
        create(:suggestion_feedback,
               daily_log: daily_log2,
               suggestion_rule: rule,
               helpfulness: false)
      end

      it "週次レポートを返す" do
        service = described_class.new(user)
        result = service.call

        expect(result[:range][:start]).to eq(week_start.to_s)
        expect(result[:range][:end]).to eq(week_end.to_s)

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

        # 提案（daily_log_suggestions がない場合は空）
        expect(result[:suggestions][:by_day]).to eq([])
      end

      it "daily_log_suggestions がある場合、提案を日付ごとに返す" do
        rule1 = SuggestionRule.find_by!(key: "test_suggestion")
        rule2 = SuggestionRule.find_by!(key: "test_suggestion2")
        create(:daily_log_suggestion,
               daily_log: daily_log1,
               suggestion_rule: rule1,
               position: 0)
        create(:daily_log_suggestion,
               daily_log: daily_log1,
               suggestion_rule: rule2,
               position: 1)
        create(:suggestion_feedback,
               daily_log: daily_log1,
               suggestion_rule: rule2,
               helpfulness: false)

        service = described_class.new(user)
        result = service.call

        expect(result[:suggestions][:by_day].size).to eq(1) # daily_log1 のみ提案あり

        day1_data = result[:suggestions][:by_day].find { |d| d[:date] == (week_start + 1.day).to_s }
        expect(day1_data).to be_present
        expect(day1_data[:items].size).to eq(2)
        expect(day1_data[:items][0]).to include(
          suggestion_key: "test_suggestion",
          title: "テスト提案1",
          message: "メッセージ1",
          helpfulness: true,
          category: "env"
        )
        expect(day1_data[:items][1]).to include(
          suggestion_key: "test_suggestion2",
          title: "テスト提案2",
          message: "メッセージ2",
          helpfulness: false,
          category: "weather"
        )

        # daily_log2 は提案がないため by_day に含まれない
        day2_data = result[:suggestions][:by_day].find { |d| d[:date] == (week_start + 2.days).to_s }
        expect(day2_data).to be_nil
      end

      it "指定した週の開始日でレポートを返す" do
        target_week_start = week_start - 7.days
        service = described_class.new(user, target_week_start)
        result = service.call

        expect(result[:range][:start]).to eq(target_week_start.to_s)
        expect(result[:range][:end]).to eq((target_week_start + 6.days).to_s)
      end
    end
  end
end
