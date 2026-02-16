# ============================================================================
# データベースシードファイル
# ============================================================================
#
# このファイルはマスタデータとテストデータを作成します。
#
# 【本番環境での動作】
#   - マスタデータ（都道府県）は投入されます（既存データは上書きされません）
#   - テストデータ（ユーザー、DailyLogなど）は作成されません
#
# 【開発・テスト環境での動作】
#   - 全てのデータが投入されます（既存データは上書きされません）
#
# 【作成されるデータ】
#
# 1. マスタデータ（本番環境でも投入）
#    - 都道府県マスタ: 全国47都道府県のデータ（コード、名称、重心座標）
# 2. テストデータ（開発・テスト環境のみ）
#    - ユーザーデータ: Alice, Bob, Carol
#    - サンプル記録データ: 過去N日分のDailyLog（環境変数 SEED_DAYS で変更可能）
#    - シグナル・提案確認用データ
#
# 【環境変数】
#   - SEED_DAYS: 作成する過去日数（デフォルト: 90日 ≒ 過去3ヶ月）
#   - SEED_VERBOSE: 詳細ログを出力（1で有効）
#
# 【投入コマンド】
# docker-compose run --rm back rails db:drop db:create db:migrate db:seed
# ============================================================================

# 環境判定
is_production = Rails.env.production?

if is_production
  puts "Running in production mode. Only master data (prefectures) will be seeded."
end

# テストユーザーの作成（開発・テスト環境のみ）
unless is_production
  puts "Seeding test users..."

  users = [
    { name: "Alice", email: "alice@example.com", password: "password123", password_confirmation: "password123" },
    { name: "Bob", email: "bob@example.com", password: "password123", password_confirmation: "password123" },
    { name: "Carol", email: "carol@example.com", password: "password123", password_confirmation: "password123" }
  ]

  users.each do |attrs|
    user = User.find_by(email: attrs[:email])
    if user
      puts "  already exists: #{user.email}"
    else
      user = User.create!(
        name: attrs[:name],
        email: attrs[:email],
        password: attrs[:password],
        password_confirmation: attrs[:password_confirmation]
      )
      puts "  created: #{user.email}"
    end
  end
else
  puts "Skipping test user creation in production."
end

# 都道府県データ
prefectures_data = [
  { code: '01', name_ja: '北海道', centroid_lat: 43.064359, centroid_lon: 141.346814 },
  { code: '02', name_ja: '青森県', centroid_lat: 40.824308, centroid_lon: 140.740259 },
  { code: '03', name_ja: '岩手県', centroid_lat: 39.703619, centroid_lon: 141.152684 },
  { code: '04', name_ja: '宮城県', centroid_lat: 38.268837, centroid_lon: 140.872103 },
  { code: '05', name_ja: '秋田県', centroid_lat: 39.718600, centroid_lon: 140.102334 },
  { code: '06', name_ja: '山形県', centroid_lat: 38.240437, centroid_lon: 140.363634 },
  { code: '07', name_ja: '福島県', centroid_lat: 37.750299, centroid_lon: 140.467521 },
  { code: '08', name_ja: '茨城県', centroid_lat: 36.341813, centroid_lon: 140.446793 },
  { code: '09', name_ja: '栃木県', centroid_lat: 36.565725, centroid_lon: 139.883565 },
  { code: '10', name_ja: '群馬県', centroid_lat: 36.390668, centroid_lon: 139.060406 },
  { code: '11', name_ja: '埼玉県', centroid_lat: 35.857428, centroid_lon: 139.648933 },
  { code: '12', name_ja: '千葉県', centroid_lat: 35.605058, centroid_lon: 140.123308 },
  { code: '13', name_ja: '東京都', centroid_lat: 35.689521, centroid_lon: 139.691704 },
  { code: '14', name_ja: '神奈川県', centroid_lat: 35.447753, centroid_lon: 139.642514 },
  { code: '15', name_ja: '新潟県', centroid_lat: 37.902418, centroid_lon: 139.023221 },
  { code: '16', name_ja: '富山県', centroid_lat: 36.695291, centroid_lon: 137.211338 },
  { code: '17', name_ja: '石川県', centroid_lat: 36.594682, centroid_lon: 136.625573 },
  { code: '18', name_ja: '福井県', centroid_lat: 36.065219, centroid_lon: 136.221642 },
  { code: '19', name_ja: '山梨県', centroid_lat: 35.664158, centroid_lon: 138.568449 },
  { code: '20', name_ja: '長野県', centroid_lat: 36.651289, centroid_lon: 138.181224 },
  { code: '21', name_ja: '岐阜県', centroid_lat: 35.391227, centroid_lon: 136.722291 },
  { code: '22', name_ja: '静岡県', centroid_lat: 34.976978, centroid_lon: 138.383054 },
  { code: '23', name_ja: '愛知県', centroid_lat: 35.180188, centroid_lon: 136.906564 },
  { code: '24', name_ja: '三重県', centroid_lat: 34.730283, centroid_lon: 136.508591 },
  { code: '25', name_ja: '滋賀県', centroid_lat: 35.004531, centroid_lon: 135.868590 },
  { code: '26', name_ja: '京都府', centroid_lat: 35.021004, centroid_lon: 135.755608 },
  { code: '27', name_ja: '大阪府', centroid_lat: 34.686316, centroid_lon: 135.519711 },
  { code: '28', name_ja: '兵庫県', centroid_lat: 34.690279, centroid_lon: 135.195511 },
  { code: '29', name_ja: '奈良県', centroid_lat: 34.685333, centroid_lon: 135.832744 },
  { code: '30', name_ja: '和歌山県', centroid_lat: 34.226034, centroid_lon: 135.167506 },
  { code: '31', name_ja: '鳥取県', centroid_lat: 35.503869, centroid_lon: 134.237672 },
  { code: '32', name_ja: '島根県', centroid_lat: 35.472297, centroid_lon: 133.050499 },
  { code: '33', name_ja: '岡山県', centroid_lat: 34.661750, centroid_lon: 133.934675 },
  { code: '34', name_ja: '広島県', centroid_lat: 34.396560, centroid_lon: 132.459622 },
  { code: '35', name_ja: '山口県', centroid_lat: 34.186121, centroid_lon: 131.470500 },
  { code: '36', name_ja: '徳島県', centroid_lat: 34.065770, centroid_lon: 134.559304 },
  { code: '37', name_ja: '香川県', centroid_lat: 34.340149, centroid_lon: 134.043444 },
  { code: '38', name_ja: '愛媛県', centroid_lat: 33.841660, centroid_lon: 132.765362 },
  { code: '39', name_ja: '高知県', centroid_lat: 33.559705, centroid_lon: 133.531080 },
  { code: '40', name_ja: '福岡県', centroid_lat: 33.606785, centroid_lon: 130.418314 },
  { code: '41', name_ja: '佐賀県', centroid_lat: 33.249367, centroid_lon: 130.298822 },
  { code: '42', name_ja: '長崎県', centroid_lat: 32.744839, centroid_lon: 129.873756 },
  { code: '43', name_ja: '熊本県', centroid_lat: 32.789828, centroid_lon: 130.741667 },
  { code: '44', name_ja: '大分県', centroid_lat: 33.238194, centroid_lon: 131.612591 },
  { code: '45', name_ja: '宮崎県', centroid_lat: 31.911090, centroid_lon: 131.423855 },
  { code: '46', name_ja: '鹿児島県', centroid_lat: 31.560148, centroid_lon: 130.557981 },
  { code: '47', name_ja: '沖縄県', centroid_lat: 26.212401, centroid_lon: 127.680932 }
]

prefectures_data.each do |prefecture_data|
  Prefecture.find_or_create_by!(code: prefecture_data[:code]) do |prefecture|
    prefecture.name_ja = prefecture_data[:name_ja]
    prefecture.centroid_lat = prefecture_data[:centroid_lat]
    prefecture.centroid_lon = prefecture_data[:centroid_lon]
  end
end

# suggestion_rules（health_rules.yml から投入、本番環境でも投入）
puts "Seeding suggestion rules from health_rules.yml..."
yaml_path = Rails.root.join("config/health_rules.yml")
if File.exist?(yaml_path)
  raw = YAML.load_file(yaml_path)["rules"] || []
  raw.each do |r|
    SuggestionRule.find_or_initialize_by(key: r["key"]).tap do |rule|
      rule.title = r.fetch("title")
      rule.message = r.fetch("message", "")
      rule.tags = Array(r["tags"])
      rule.severity = r.fetch("severity").to_i
      rule.category = r.fetch("category", "env")
      rule.level = r["level"].to_s.presence
      rule.concerns = Array(r["concerns"])
      rule.reason_text = r["reason_text"].to_s.presence
      rule.evidence_text = r["evidence_text"].to_s.presence
      rule.condition = r.fetch("condition", "")
      rule.group = r["group"].to_s.presence
      rule.save!
    end
  end
  puts "  Loaded #{SuggestionRule.count} suggestion rules"
else
  puts "  WARNING: health_rules.yml not found, skipping suggestion_rules"
end

# 関心テーママスタ（関心トピック）
# label_ja, description_ja はフロントの関心トピック登録UIで表示されます。
unless is_production
  puts "Seeding concern topics..."

  concern_topics = [
    {
      key: "sleep_time",
      label_ja: "睡眠時間",
      description_ja: "睡眠時間の過不足に関する提案をします。",
      rule_concerns: [ "sleep_time" ],
      position: 0
    },
    {
      key: "weather_pain",
      label_ja: "気象病・天気痛",
      description_ja: "気圧変動や低気圧による頭痛・倦怠感など、天気痛に関する提案をします。",
      rule_concerns: [ "weather_pain" ],
      position: 1
    },
    {
      key: "dryness_infection",
      label_ja: "乾燥・ウイルス感染リスク",
      description_ja: "乾燥や低湿度によるウイルス感染リスク・喉や肌の不調に関する提案をします。",
      rule_concerns: [ "dryness_infection" ],
      position: 2
    },
    {
      key: "heatstroke",
      label_ja: "熱中症",
      description_ja: "猛暑や高湿度による熱中症リスクに関する提案をします。",
      rule_concerns: [ "heatstroke" ],
      position: 3
    },
    {
      key: "heat_shock",
      label_ja: "ヒートショック",
      description_ja: "気温差や入浴時の急激な温度変化によるヒートショックリスクに関する提案をします。",
      rule_concerns: [ "heat_shock" ],
      position: 4
    }
  ]

  concern_topics.each do |attrs|
    topic = ConcernTopic.find_or_initialize_by(key: attrs[:key])
    topic.assign_attributes(attrs)
    topic.save!
  end

  # Alice に全関心トピックを登録
  alice = User.find_by(email: 'alice@example.com')
  if alice
    ConcernTopic.find_each do |topic|
      UserConcernTopic.find_or_create_by!(user: alice, concern_topic: topic)
    end
    puts "  Registered all concern topics for Alice (#{ConcernTopic.count} topics)"
  end
end

# サンプルの日次記録データ（開発・テスト環境のみ、デフォルトで過去3ヶ月分 ≒ 90日）
unless is_production
  sample_days = ENV.fetch('SEED_DAYS', '90').to_i
  verbose_logs = ENV['SEED_VERBOSE'] == '1'
  puts "Creating sample daily logs... (days=#{sample_days}, verbose=#{verbose_logs})"
else
  puts "Skipping sample data creation in production."
end

# Aliceのサンプル記録（開発・テスト環境のみ）
unless is_production
  alice = User.find_by(email: 'alice@example.com')
  if alice
    # 過去30日分のサンプルデータ（今日は除く）
    ActiveRecord::Base.transaction do
      (1..sample_days).each do |days_ago|
        date = Date.current - days_ago.days

        # 既存の記録があるかチェック
        existing_log = DailyLog.find_by(user: alice, date: date)
        next if existing_log

        # ランダムな体調データを生成
        sleep_hours = rand(5.0..9.0).round(1)
        mood_score = rand(1..5)      # 気分スコア（1〜5）
        fatigue_score = rand(1..5)   # 疲労感スコア（1〜5）

        # メモ（気分と疲労感を考慮）
        notes = case [ mood_score, fatigue_score ]
        in [ 4..5, 1..3 ]
          "体調が良く、充実した一日でした。疲れも少なく快調です。"
        in [ 3, 1..4 ]
          "普通の一日でした。特に問題なし。"
        in [ 2..3, 4..5 ]
          "少し疲れを感じました。"
        in [ 1..2, 4..5 ]
          "体調が優れませんでした。疲労感が強いです。"
        else
          "普通の一日でした。"
        end

        # デフォルトの都道府県（東京都）を取得
        default_prefecture = Prefecture.find_by(code: '13')

        DailyLog.create!(
          user: alice,
          prefecture: default_prefecture,
          date: date,
          sleep_hours: sleep_hours,
          mood: mood_score,
          fatigue: fatigue_score,
          fatigue_level: fatigue_score,
          note: notes,
          self_score: rand(1..3)
        )

        puts "  Created daily log for Alice on #{date}: sleep=#{sleep_hours}h, mood=#{mood_score}, fatigue=#{fatigue_score}" if verbose_logs
      end
    end

    # ==== 今日のAlice用: 固定の天気パターン＋提案が多めに出るセットアップ ====
    puts "Creating todays context for Alice (fixed weather pattern for suggestions)..."

    today = Date.current
    # デフォルト都道府県（東京）をAliceに付与
    default_prefecture = alice.prefecture || Prefecture.find_by(code: '13')
    if default_prefecture && alice.prefecture.nil?
      alice.update!(prefecture: default_prefecture)
    end

    if default_prefecture
      # 今日のDailyLog（睡眠不足）を固定値で作成
      DailyLog.find_or_create_by!(user: alice, date: today) do |log|
        log.prefecture = default_prefecture
        log.sleep_hours = 5.5
        log.mood = 2
        log.fatigue = 4
        log.fatigue_level = 4
        log.note = "シード用テストデータ: 睡眠不足＋環境リスク高めの一日"
        log.self_score = 2
      end

      # 今日の固定的な天気パターン（猛暑＋乾燥＋低気圧気味）
      fixed_metrics = {
        "temperature_c" => 36.0,   # heatstroke_Danger
        "min_temperature_c" => 10.0, # heat_shock_Warning
        "humidity_pct"  => 25.0,   # dryness_Warning
        "pressure_hpa"  => 975.0,  # 低気圧
        "max_pressure_drop_1h_awake"   => 0.0,
        "low_pressure_duration_1003h"  => 3.0,   # weather_pain_low_1003_Warning (>= 3.0)
        "low_pressure_duration_1007h"  => 0.0,
        "pressure_range_3h_awake"      => 0.0,
        "pressure_jitter_3h_awake"     => 0.0
      }

      WeatherSnapshot.find_or_initialize_by(
        prefecture: default_prefecture,
        date: today
      ).tap do |snapshot|
        snapshot.metrics = (snapshot.metrics || {}).merge(fixed_metrics)
        snapshot.save!
      end

      # envカテゴリのルールを使って、Aliceの都道府県向けSuggestionSnapshotを事前生成
      env_rules = ::Suggestion::RuleRegistry.all.select { |r| r.category == "env" }
      ctx = {
        "temperature_c"     => fixed_metrics["temperature_c"].to_f,
        "min_temperature_c" => fixed_metrics["min_temperature_c"].to_f,
        "humidity_pct"      => fixed_metrics["humidity_pct"].to_f,
        "pressure_hpa"      => fixed_metrics["pressure_hpa"].to_f,
        "max_pressure_drop_1h_awake"   => (fixed_metrics["max_pressure_drop_1h_awake"] || 0).to_f,
        "low_pressure_duration_1003h"  => (fixed_metrics["low_pressure_duration_1003h"] || 0).to_f,
        "low_pressure_duration_1007h"  => (fixed_metrics["low_pressure_duration_1007h"] || 0).to_f,
        "pressure_range_3h_awake"      => (fixed_metrics["pressure_range_3h_awake"] || 0).to_f,
        "pressure_jitter_3h_awake"     => (fixed_metrics["pressure_jitter_3h_awake"] || 0).to_f
      }

      env_suggestions = ::Suggestion::RuleEngine.call(
        rules: env_rules,
        context: ctx,
        limit: 20,
        tag_diversity: false
      )

      SuggestionSnapshot.where(date: today, prefecture_id: default_prefecture.id).delete_all

      if env_suggestions.any?
        rule_by_key = SuggestionRule.all.to_h { |r| [ r.key, r.id ] }
        records = env_suggestions.filter_map do |s|
          rule_id = rule_by_key[s.key]
          next unless rule_id

          {
            date: today,
            prefecture_id: default_prefecture.id,
            rule_id: rule_id,
            metadata: ctx.dup,
            created_at: Time.current,
            updated_at: Time.current
          }
        end
        SuggestionSnapshot.insert_all!(records) if records.any?
        puts "  Created #{env_suggestions.size} env suggestions for Alice (#{default_prefecture.name_ja}) on #{today}"
      else
        puts "  No env suggestions generated for Alice on #{today}"
      end

      # 週間レポート「提案」タブ用: daily_log_suggestions と suggestion_feedbacks を追加
      puts "Creating daily_log_suggestions for weekly report..."
      week_start = Date.current.beginning_of_week(:monday)
      target_dates = ((week_start - 7.days)..(week_start + 6.days)).to_a
      suggestion_keys = %w[heatstroke_Warning heat_shock_Caution weather_pain_drop_Caution dryness_Warning]
      rules_by_key = SuggestionRule.where(key: suggestion_keys).index_by(&:key)

      target_dates.each do |date|
        log = DailyLog.find_by(user: alice, date: date)
        next unless log

        keys_to_use = suggestion_keys.sample(rand(1..3))
        keys_to_use.each_with_index do |rule_key, pos|
          rule = rules_by_key[rule_key]
          next unless rule
          next if DailyLogSuggestion.exists?(daily_log_id: log.id, rule_id: rule.id)

          DailyLogSuggestion.create!(
            daily_log_id: log.id,
            suggestion_rule: rule,
            position: pos
          )

          # 約半分にフィードバックを付与
          next unless rand < 0.5

          SuggestionFeedback.find_or_create_by!(daily_log_id: log.id, suggestion_rule: rule) do |fb|
            fb.helpfulness = rand < 0.7
          end
        end
      end
      puts "  Created daily_log_suggestions for Alice (#{target_dates.size} days)"
    end
  end

  # Bobのサンプル記録
  bob = User.find_by(email: 'bob@example.com')
  if bob
    # 過去30日分のサンプルデータ（今日は除く）
    ActiveRecord::Base.transaction do
      (1..sample_days).each do |days_ago|
        date = Date.current - days_ago.days

        # 既存の記録があるかチェック
        existing_log = DailyLog.find_by(user: bob, date: date)
        next if existing_log

        # ランダムな体調データを生成
        sleep_hours = rand(5.0..9.0).round(1)
        mood_score = rand(1..5)      # 気分スコア（1〜5）
        fatigue_score = rand(1..5)   # 疲労感スコア（1〜5）

        # メモ（気分と疲労感を考慮）
        notes = case [ mood_score, fatigue_score ]
        in [ 4..5, 1..3 ]
          "体調が良く、充実した一日でした。疲れも少なく快調です。"
        in [ 3, 1..4 ]
          "普通の一日でした。特に問題なし。"
        in [ 2..3, 4..5 ]
          "少し疲れを感じました。"
        in [ 1..2, 4..5 ]
          "体調が優れませんでした。疲労感が強いです。"
        else
          "普通の一日でした。"
        end

        # デフォルトの都道府県（東京都）を取得
        default_prefecture = Prefecture.find_by(code: '13')

        DailyLog.create!(
          user: bob,
          prefecture: default_prefecture,
          date: date,
          sleep_hours: sleep_hours,
          mood: mood_score,
          fatigue: fatigue_score,
          fatigue_level: fatigue_score,
          note: notes,
          self_score: rand(1..3)
        )

        puts "  Created daily log for Bob on #{date}: sleep=#{sleep_hours}h, mood=#{mood_score}, fatigue=#{fatigue_score}" if verbose_logs
      end
    end

    # Bob にも週間レポート用の daily_log_suggestions を追加
    week_start = Date.current.beginning_of_week(:monday)
    bob_target_dates = ((week_start - 7.days)..(week_start + 6.days)).to_a
    if bob_target_dates.any? { |d| DailyLog.exists?(user: bob, date: d) }
      bob_suggestion_keys = %w[heatstroke_Caution weather_pain_drop_Warning]
      bob_rules_by_key = SuggestionRule.where(key: bob_suggestion_keys).index_by(&:key)

      bob_target_dates.each do |date|
        log = DailyLog.find_by(user: bob, date: date)
        next unless log

        keys_to_use = bob_suggestion_keys.sample(rand(1..2))
        keys_to_use.each_with_index do |rule_key, pos|
          rule = bob_rules_by_key[rule_key]
          next unless rule
          next if DailyLogSuggestion.exists?(daily_log_id: log.id, rule_id: rule.id)

          DailyLogSuggestion.create!(
            daily_log_id: log.id,
            suggestion_rule: rule,
            position: pos
          )

          SuggestionFeedback.find_or_create_by!(daily_log_id: log.id, suggestion_rule: rule) do |fb|
            fb.helpfulness = rand < 0.6
          end
        end
      end
      puts "  Created daily_log_suggestions for Bob"
    end
  end

end

puts "Seed completed."
