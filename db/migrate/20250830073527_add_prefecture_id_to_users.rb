class AddPrefectureIdToUsers < ActiveRecord::Migration[7.2]
  def change
    add_reference :users, :prefecture, null: true, foreign_key: true
  end
end
