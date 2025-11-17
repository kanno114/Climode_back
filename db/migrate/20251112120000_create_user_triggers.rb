class CreateUserTriggers < ActiveRecord::Migration[7.2]
  def change
    create_table :user_triggers do |t|
      t.references :user, null: false, foreign_key: { on_delete: :restrict }
      t.references :trigger, null: false, foreign_key: { on_delete: :restrict }

      t.timestamps
    end

    add_index :user_triggers, [ :user_id, :trigger_id ], unique: true
  end
end
