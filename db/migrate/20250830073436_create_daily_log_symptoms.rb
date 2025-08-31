class CreateDailyLogSymptoms < ActiveRecord::Migration[7.2]
  def change
    create_table :daily_log_symptoms do |t|
      t.references :daily_log, null: false, foreign_key: true
      t.references :symptom, null: false, foreign_key: true

      t.timestamps
    end
  end
end
