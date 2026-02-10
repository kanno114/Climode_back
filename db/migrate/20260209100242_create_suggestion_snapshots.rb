class CreateSuggestionSnapshots < ActiveRecord::Migration[7.2]
  def change
    create_table :suggestion_snapshots do |t|
      t.date :date, null: false
      t.string :prefecture, null: false
      t.string :rule_key, null: false
      t.string :title, null: false
      t.text :message
      t.jsonb :tags, default: []
      t.integer :severity, null: false
      t.string :category, null: false
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :suggestion_snapshots, [ :date, :prefecture ]
    add_index :suggestion_snapshots, [ :date, :prefecture, :rule_key ], unique: true, name: "index_suggestion_snapshots_on_date_pref_rule"
    add_index :suggestion_snapshots, :tags, using: :gin
  end
end
