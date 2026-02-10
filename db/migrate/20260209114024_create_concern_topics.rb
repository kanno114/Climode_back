class CreateConcernTopics < ActiveRecord::Migration[7.2]
  def change
    create_table :concern_topics do |t|
      t.string :key, null: false
      t.string :label_ja, null: false
      t.text :description_ja
      t.jsonb :rule_concerns, null: false, default: []
      t.integer :position
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :concern_topics, :key, unique: true
  end
end
