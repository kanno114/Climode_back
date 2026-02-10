class DropSignalFeedbacksTable < ActiveRecord::Migration[7.2]
  def up
    drop_table :signal_feedbacks
  end

  def down
    create_table :signal_feedbacks do |t|
      t.references :daily_log, null: false, foreign_key: { on_delete: :cascade }
      t.string :trigger_key, null: false
      t.integer :match, null: false

      t.timestamps
    end
    add_index :signal_feedbacks, [ :daily_log_id, :trigger_key ], unique: true
    add_check_constraint :signal_feedbacks, "match >= 1 AND match <= 5", name: "check_signal_feedback_match_range"
  end
end
