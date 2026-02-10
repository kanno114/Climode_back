class CreateUserConcernTopics < ActiveRecord::Migration[7.2]
  def change
    create_table :user_concern_topics do |t|
      t.references :user, null: false, foreign_key: true
      t.string :concern_topic_key, null: false

      t.timestamps
    end
    add_index :user_concern_topics, [ :user_id, :concern_topic_key ], unique: true, name: "index_user_concern_topics_on_user_and_key"
  end
end
