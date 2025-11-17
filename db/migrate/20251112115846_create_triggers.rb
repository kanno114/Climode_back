class CreateTriggers < ActiveRecord::Migration[7.2]
  def change
    create_table :triggers do |t|
      t.string :key, null: false
      t.string :label, null: false
      t.string :category, null: false
      t.boolean :is_active, null: false, default: true
      t.integer :version, null: false
      t.jsonb :rule, null: true, default: {}

      t.timestamps
    end

    add_index :triggers, :key, unique: true
    add_check_constraint :triggers, "category IN ('env', 'body')", name: "triggers_category_check"
  end
end
