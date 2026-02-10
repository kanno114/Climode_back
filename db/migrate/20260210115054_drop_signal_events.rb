class DropSignalEvents < ActiveRecord::Migration[7.2]
  def up
    drop_table :signal_events
  end

  def down
    create_table :signal_events do |t|
      t.references :user, null: false, foreign_key: true
      t.string :trigger_key, null: false
      t.string :category, null: false
      t.string :level, null: false
      t.integer :priority, null: false
      t.datetime :evaluated_at, null: false
      t.jsonb :meta, default: {}

      t.timestamps
    end
    add_index :signal_events,
              "user_id, trigger_key, date(evaluated_at)",
              unique: true,
              name: "index_signal_events_on_user_trigger_evaluated"
    add_check_constraint :signal_events,
                         "category::text = ANY (ARRAY['env'::character varying, 'body'::character varying]::text[])",
                         name: "signal_events_category_check"
  end
end
