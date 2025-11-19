class DropSymptomsTables < ActiveRecord::Migration[7.2]
  def change
    drop_table :daily_log_symptoms do |t|
      t.references :daily_log, null: false, foreign_key: true
      t.references :symptom, null: false, foreign_key: true
      t.timestamps
    end

    drop_table :symptoms do |t|
      t.string :code
      t.string :name
      t.timestamps
    end
  end
end
