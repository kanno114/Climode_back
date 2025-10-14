class CreateDailyLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :daily_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :prefecture, null: false, foreign_key: true
      t.date :date, null: false
      t.decimal :sleep_hours, precision: 4, scale: 1
      t.integer :mood
      t.integer :fatigue
      t.integer :score
      t.integer :self_score
      t.text :memo

      t.timestamps
    end
    add_index :daily_logs, [ :user_id, :date ], unique: true
  end
end
