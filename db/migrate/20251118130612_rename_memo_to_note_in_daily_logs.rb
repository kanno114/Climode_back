class RenameMemoToNoteInDailyLogs < ActiveRecord::Migration[7.2]
  def change
    rename_column :daily_logs, :memo, :note
  end
end
