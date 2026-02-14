# frozen_string_literal: true

class CreateSuggestionRules < ActiveRecord::Migration[7.2]
  def change
    create_table :suggestion_rules do |t|
      t.string :key, null: false
      t.string :title, null: false
      t.text :message
      t.jsonb :tags, default: [], null: false
      t.integer :severity, null: false
      t.string :category, null: false, default: "env"
      t.string :level
      t.jsonb :concerns, default: [], null: false
      t.text :reason_text
      t.text :evidence_text
      t.string :condition, null: false
      t.string :group

      t.timestamps
    end

    add_index :suggestion_rules, :key, unique: true
  end
end
