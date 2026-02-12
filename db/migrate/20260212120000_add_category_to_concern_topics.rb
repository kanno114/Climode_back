class AddCategoryToConcernTopics < ActiveRecord::Migration[7.2]
  def change
    add_column :concern_topics, :category, :string
  end
end
