# frozen_string_literal: true

class RemoveHelpfulnessAndMatchScoreFromDailyLogs < ActiveRecord::Migration[7.2]
  def change
    remove_check_constraint :daily_logs, name: "check_helpfulness_range"
    remove_check_constraint :daily_logs, name: "check_match_score_range"
    remove_column :daily_logs, :helpfulness, :integer
    remove_column :daily_logs, :match_score, :integer
  end
end
