# frozen_string_literal: true

class ChangeSuggestionSnapshotsPrefectureToForeignKey < ActiveRecord::Migration[7.2]
  def change
    # 1. prefecture_id カラム追加
    add_reference :suggestion_snapshots, :prefecture, null: true, foreign_key: true

    # 2. 既存データを移行（prefecture 文字列 → prefecture_id）
    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE suggestion_snapshots
          SET prefecture_id = prefectures.id
          FROM prefectures
          WHERE suggestion_snapshots.prefecture = prefectures.code
        SQL
      end
    end

    # 3. NOT NULL に変更
    change_column_null :suggestion_snapshots, :prefecture_id, false

    # 4. 古いインデックスを削除（prefecture カラム削除前に必要）
    remove_index :suggestion_snapshots, name: "index_suggestion_snapshots_on_date_pref_rule"
    remove_index :suggestion_snapshots, name: "index_suggestion_snapshots_on_date_and_prefecture"

    # 5. prefecture カラム削除
    remove_column :suggestion_snapshots, :prefecture

    # 6. ユニークインデックスの更新（date, prefecture_id, rule_key）
    add_index :suggestion_snapshots, [ :date, :prefecture_id, :rule_key ], unique: true, name: "index_suggestion_snapshots_on_date_pref_rule"
    add_index :suggestion_snapshots, [ :date, :prefecture_id ], name: "index_suggestion_snapshots_on_date_and_prefecture"
  end
end
