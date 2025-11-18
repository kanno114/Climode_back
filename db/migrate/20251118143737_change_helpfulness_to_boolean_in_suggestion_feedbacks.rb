class ChangeHelpfulnessToBooleanInSuggestionFeedbacks < ActiveRecord::Migration[7.2]
  def up
    # 既存のデータを変換（1-3はfalse、4-5はtrue）
    # まずinteger型のまま変換（カラムがinteger型であることを前提）
    execute <<-SQL
      UPDATE suggestion_feedbacks
      SET helpfulness = CASE
        WHEN helpfulness::integer >= 4 THEN 1
        ELSE 0
      END
      WHERE helpfulness IS NOT NULL
    SQL

    # チェック制約を削除（型変換前に削除）
    begin
      remove_check_constraint :suggestion_feedbacks, name: "check_suggestion_feedback_helpfulness_range"
    rescue ActiveRecord::StatementInvalid
      # チェック制約が存在しない場合は無視
    end

    # カラムをbooleanに変更（USING句で明示的に型変換を指定）
    execute <<-SQL
      ALTER TABLE suggestion_feedbacks
      ALTER COLUMN helpfulness TYPE boolean
      USING (helpfulness::integer = 1)
    SQL

    # null制約とデフォルト値を設定
    change_column_null :suggestion_feedbacks, :helpfulness, false
    change_column_default :suggestion_feedbacks, :helpfulness, false
  end

  def down
    # booleanをintegerに戻す
    execute <<-SQL
      ALTER TABLE suggestion_feedbacks
      ALTER COLUMN helpfulness TYPE integer
      USING (CASE WHEN helpfulness THEN 1 ELSE 0 END)
    SQL

    change_column_null :suggestion_feedbacks, :helpfulness, false

    # チェック制約を再追加
    add_check_constraint :suggestion_feedbacks, "helpfulness >= 1 AND helpfulness <= 5", name: "check_suggestion_feedback_helpfulness_range"
  end
end
