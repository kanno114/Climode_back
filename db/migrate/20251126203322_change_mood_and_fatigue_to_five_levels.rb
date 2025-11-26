class ChangeMoodAndFatigueToFiveLevels < ActiveRecord::Migration[7.2]
  def up
    # 既存データの移行: -5〜5 を 1〜5 に変換
    # -5 → 1, -4 → 1, -3 → 2, -2 → 2, -1 → 3, 0 → 3, 1 → 3, 2 → 4, 3 → 4, 4 → 5, 5 → 5
    execute <<-SQL
      UPDATE daily_logs
      SET mood = CASE
        WHEN mood IS NULL THEN NULL
        WHEN mood <= -3 THEN 1
        WHEN mood <= -1 THEN 2
        WHEN mood <= 1 THEN 3
        WHEN mood <= 3 THEN 4
        ELSE 5
      END
      WHERE mood IS NOT NULL;
    SQL

    execute <<-SQL
      UPDATE daily_logs
      SET fatigue = CASE
        WHEN fatigue IS NULL THEN NULL
        WHEN fatigue <= -3 THEN 1
        WHEN fatigue <= -1 THEN 2
        WHEN fatigue <= 1 THEN 3
        WHEN fatigue <= 3 THEN 4
        ELSE 5
      END
      WHERE fatigue IS NOT NULL;
    SQL

    # チェック制約の更新
    remove_check_constraint :daily_logs, name: "check_mood_range"
    remove_check_constraint :daily_logs, name: "check_fatigue_range"

    add_check_constraint :daily_logs, "mood >= 1 AND mood <= 5", name: "check_mood_range"
    add_check_constraint :daily_logs, "fatigue >= 1 AND fatigue <= 5", name: "check_fatigue_range"
  end

  def down
    # チェック制約を元に戻す
    remove_check_constraint :daily_logs, name: "check_mood_range"
    remove_check_constraint :daily_logs, name: "check_fatigue_range"

    add_check_constraint :daily_logs, "mood >= -5 AND mood <= 5", name: "check_mood_range"
    add_check_constraint :daily_logs, "fatigue >= -5 AND fatigue <= 5", name: "check_fatigue_range"

    # データの復元は複雑なため、ここでは制約のみ復元
    # 実際のデータ復元が必要な場合は、バックアップから復元することを推奨
  end
end
