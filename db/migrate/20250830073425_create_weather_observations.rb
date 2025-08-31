class CreateWeatherObservations < ActiveRecord::Migration[7.2]
  def change
    create_table :weather_observations do |t|
      t.references :daily_log, null: false, foreign_key: true
      t.decimal :temperature_c, precision: 4, scale: 1
      t.decimal :humidity_pct, precision: 5, scale: 2
      t.decimal :pressure_hpa, precision: 6, scale: 1
      t.datetime :observed_at
      t.jsonb :snapshot

      t.timestamps
    end
  end
end
