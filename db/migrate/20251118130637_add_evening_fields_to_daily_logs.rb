class AddEveningFieldsToDailyLogs < ActiveRecord::Migration[7.2]
  def change
    add_column :daily_logs, :helpfulness, :integer
    add_column :daily_logs, :match_score, :integer
    add_column :daily_logs, :fatigue_level, :integer

    add_check_constraint :daily_logs, "helpfulness >= 1 AND helpfulness <= 5", name: "check_helpfulness_range"
    add_check_constraint :daily_logs, "match_score >= 1 AND match_score <= 5", name: "check_match_score_range"
    add_check_constraint :daily_logs, "fatigue_level >= 1 AND fatigue_level <= 5", name: "check_fatigue_level_range"
  end
end
