# frozen_string_literal: true

class ChangeUserConcernTopicsConcernTopicToForeignKey < ActiveRecord::Migration[7.2]
  def change
    # 1. concern_topic_id カラム追加
    add_reference :user_concern_topics, :concern_topic, null: true, foreign_key: true

    # 2. 既存データを移行（concern_topic_key → concern_topic_id）
    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE user_concern_topics
          SET concern_topic_id = concern_topics.id
          FROM concern_topics
          WHERE user_concern_topics.concern_topic_key = concern_topics.key
        SQL
      end
    end

    # 3. NOT NULL に変更
    change_column_null :user_concern_topics, :concern_topic_id, false

    # 4. concern_topic_key カラム削除
    remove_index :user_concern_topics, name: "index_user_concern_topics_on_user_and_key"
    remove_column :user_concern_topics, :concern_topic_key

    # 5. ユニークインデックス（user_id, concern_topic_id）
    add_index :user_concern_topics, [ :user_id, :concern_topic_id ], unique: true, name: "index_user_concern_topics_on_user_and_concern_topic"
  end
end
