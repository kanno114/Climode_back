# frozen_string_literal: true

class RemoveScoreFromDailyLogs < ActiveRecord::Migration[7.2]
  def up
    remove_check_constraint :daily_logs, name: "check_score_range"
    remove_column :daily_logs, :score
  end

  def down
    add_column :daily_logs, :score, :integer
    add_check_constraint :daily_logs, "score >= 0 AND score <= 100", name: "check_score_range"
  end
end
