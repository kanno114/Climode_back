# ============================================================================
# データベースシードファイル
# ============================================================================
#
# このファイルはマスタデータとテストデータを作成します。
#
# 【本番環境での動作】
#   - マスタデータ（都道府県、suggestion_rules、関心トピック）が投入されます
#   - テストデータ（ユーザー、DailyLogなど）は作成されません
#
# 【開発・テスト環境での動作】
#   - 全てのデータが投入されます（既存データは上書きされません）
#
# 【環境変数】
#   - SEED_DAYS: 作成する過去日数（デフォルト: 90日 ≒ 過去3ヶ月）
#   - SEED_VERBOSE: 詳細ログを出力（1で有効）
#
# 【投入コマンド】
# docker-compose run --rm back rails db:drop db:create db:migrate db:seed
# ============================================================================

# マスタデータ（本番環境でも投入）
load Rails.root.join("db/seeds/master_data.rb")

unless Rails.env.production?
  # テストユーザー作成
  load Rails.root.join("db/seeds/test_users.rb")

  # サンプルデータ（DailyLog、WeatherSnapshot、提案スナップショット、フィードバック）
  load Rails.root.join("db/seeds/sample_data.rb")
end

puts "Seed completed."
