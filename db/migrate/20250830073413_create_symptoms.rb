class CreateSymptoms < ActiveRecord::Migration[7.2]
  def change
    create_table :symptoms do |t|
      t.string :code
      t.string :name

      t.timestamps
    end
    add_index :symptoms, :code, unique: true
    add_index :symptoms, :name, unique: true
  end
end
