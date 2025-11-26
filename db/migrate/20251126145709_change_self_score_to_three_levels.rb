class ChangeSelfScoreToThreeLevels < ActiveRecord::Migration[7.2]
  def up
    # 既存のデータを変換（0-33 → 1, 34-66 → 2, 67-100 → 3）
    execute <<-SQL
      UPDATE daily_logs
      SET self_score = CASE
        WHEN self_score IS NULL THEN NULL
        WHEN self_score <= 33 THEN 1
        WHEN self_score <= 66 THEN 2
        ELSE 3
      END
      WHERE self_score IS NOT NULL;
    SQL

    # 制約を削除
    remove_check_constraint :daily_logs, name: "check_self_score_range"

    # 新しい制約を追加（1〜3）
    add_check_constraint :daily_logs, "self_score >= 1 AND self_score <= 3", name: "check_self_score_range"
  end

  def down
    remove_check_constraint :daily_logs, name: "check_self_score_range"
    add_check_constraint :daily_logs, "self_score >= 0 AND self_score <= 100", name: "check_self_score_range"
  end
end
