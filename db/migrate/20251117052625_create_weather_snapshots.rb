class CreateWeatherSnapshots < ActiveRecord::Migration[7.2]
  def change
    create_table :weather_snapshots do |t|
      t.references :prefecture, null: false, foreign_key: true
      t.date :date, null: false
      t.jsonb :metrics, default: {}

      t.timestamps
    end

    add_index :weather_snapshots, [ :prefecture_id, :date ], unique: true
  end
end
