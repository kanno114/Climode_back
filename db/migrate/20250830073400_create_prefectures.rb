class CreatePrefectures < ActiveRecord::Migration[7.2]
  def change
    create_table :prefectures do |t|
      t.string :code, null: false
      t.string :name_ja, null: false
      t.decimal :centroid_lat, precision: 8, scale: 6
      t.decimal :centroid_lon, precision: 9, scale: 6

      t.timestamps
    end
    add_index :prefectures, :code, unique: true
  end
end
