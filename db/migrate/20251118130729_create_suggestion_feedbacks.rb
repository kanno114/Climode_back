class CreateSuggestionFeedbacks < ActiveRecord::Migration[7.2]
  def change
    create_table :suggestion_feedbacks do |t|
      t.references :daily_log, null: false, foreign_key: { on_delete: :cascade }
      t.string :suggestion_key, null: false
      t.integer :helpfulness, null: false

      t.timestamps
    end

    add_index :suggestion_feedbacks, [ :daily_log_id, :suggestion_key ], unique: true
    add_check_constraint :suggestion_feedbacks, "helpfulness >= 1 AND helpfulness <= 5", name: "check_suggestion_feedback_helpfulness_range"
  end
end
