# frozen_string_literal: true

class AddLevelToSuggestionTables < ActiveRecord::Migration[7.2]
  def change
    add_column :suggestion_snapshots, :level, :string, null: true
    add_column :daily_log_suggestions, :level, :string, null: true
  end
end
