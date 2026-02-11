# frozen_string_literal: true

class CreateDailyLogSuggestions < ActiveRecord::Migration[7.2]
  def change
    create_table :daily_log_suggestions do |t|
      t.references :daily_log, null: false, foreign_key: true
      t.string :suggestion_key, null: false
      t.string :title, null: false
      t.text :message
      t.jsonb :tags, default: [], null: false
      t.integer :severity, null: false
      t.string :category, null: false
      t.integer :position

      t.timestamps
    end

    add_index :daily_log_suggestions, [ :daily_log_id, :suggestion_key ],
              unique: true,
              name: "index_daily_log_suggestions_on_daily_log_and_suggestion_key"
  end
end
