# ============================================================================
# サンプルデータ（開発・テスト環境のみ）
# - DailyLog（Alice・Bob、過去90日分）
# - WeatherSnapshot（東京・大阪、過去90日分）
# - SuggestionSnapshot（東京・大阪、過去90日分）
# - DailyLogSuggestion / SuggestionFeedback
# - PushSubscription（ダミー）
# ============================================================================

sample_days = ENV.fetch("SEED_DAYS", "90").to_i
verbose = ENV["SEED_VERBOSE"] == "1"

# ============================================================================
# ヘルパーメソッド
# ============================================================================

def generate_note(mood_score, fatigue_score)
  case [ mood_score, fatigue_score ]
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
end

def create_sample_daily_logs(user:, prefecture:, days:, verbose: false)
  ActiveRecord::Base.transaction do
    (1..days).each do |days_ago|
      date = Date.current - days_ago.days
      next if DailyLog.exists?(user: user, date: date)

      sleep_hours = rand(5.0..9.0).round(1)
      mood_score = rand(1..5)
      fatigue_score = rand(1..5)

      DailyLog.create!(
        user: user,
        prefecture: prefecture,
        date: date,
        sleep_hours: sleep_hours,
        mood: mood_score,
        fatigue: fatigue_score,
        fatigue_level: fatigue_score,
        note: generate_note(mood_score, fatigue_score),
        self_score: rand(1..3)
      )

      puts "  Created daily log for #{user.name} on #{date}" if verbose
    end
  end
end

# 季節感のあるWeatherSnapshotを生成する
# 月ごとの基準値を使い、日ごとにランダムな変動を加える
def seasonal_weather_metrics(date)
  month = date.month

  # 月ごとの基準値（日本の一般的な気候パターン）
  base = case month
  when 12, 1, 2  # 冬
    { temp: 5.0, min_temp: 0.0, humidity: 45.0, pressure: 1018.0 }
  when 3, 4      # 春
    { temp: 14.0, min_temp: 7.0, humidity: 55.0, pressure: 1015.0 }
  when 5, 6      # 初夏・梅雨
    { temp: 22.0, min_temp: 16.0, humidity: 70.0, pressure: 1010.0 }
  when 7, 8      # 真夏
    { temp: 30.0, min_temp: 25.0, humidity: 75.0, pressure: 1008.0 }
  when 9, 10     # 秋
    { temp: 20.0, min_temp: 14.0, humidity: 60.0, pressure: 1015.0 }
  when 11        # 晩秋
    { temp: 12.0, min_temp: 5.0, humidity: 55.0, pressure: 1018.0 }
  end

  temp = (base[:temp] + rand(-5.0..5.0)).round(1)
  min_temp = (base[:min_temp] + rand(-3.0..3.0)).round(1)
  humidity = (base[:humidity] + rand(-15.0..15.0)).clamp(10.0, 100.0).round(1)
  pressure = (base[:pressure] + rand(-15.0..10.0)).round(1)

  # 気圧変動パターン（低気圧日をランダムに発生させる）
  low_pressure_day = pressure < 1005.0
  pressure_drop = low_pressure_day ? rand(0.5..3.0).round(1) : rand(0.0..0.5).round(1)
  low_1003_hours = low_pressure_day ? rand(1.0..6.0).round(1) : 0.0
  low_1007_hours = pressure < 1007.0 ? rand(1.0..4.0).round(1) : 0.0

  {
    "temperature_c" => temp,
    "min_temperature_c" => [ min_temp, temp - 2.0 ].min.round(1),
    "humidity_pct" => humidity,
    "pressure_hpa" => pressure,
    "max_pressure_drop_1h_awake" => pressure_drop,
    "low_pressure_duration_1003h" => low_1003_hours,
    "low_pressure_duration_1007h" => low_1007_hours,
    "pressure_range_3h_awake" => rand(0.0..4.0).round(1),
    "pressure_jitter_3h_awake" => rand(0.0..2.0).round(1)
  }
end

def create_weather_snapshots(prefecture:, days:, verbose: false)
  (0..days).each do |days_ago|
    date = Date.current - days_ago.days
    WeatherSnapshot.find_or_create_by!(prefecture: prefecture, date: date) do |ws|
      ws.metrics = seasonal_weather_metrics(date)
      puts "  Created weather snapshot for #{prefecture.name_ja} on #{date}" if verbose
    end
  end
end

def build_weather_context(ws)
  {
    "temperature_c" => (ws.metrics["temperature_c"] || 0).to_f,
    "min_temperature_c" => (ws.metrics["min_temperature_c"] || 0).to_f,
    "humidity_pct" => (ws.metrics["humidity_pct"] || 0).to_f,
    "pressure_hpa" => (ws.metrics["pressure_hpa"] || 0).to_f,
    "max_pressure_drop_1h_awake" => (ws.metrics["max_pressure_drop_1h_awake"] || 0).to_f,
    "low_pressure_duration_1003h" => (ws.metrics["low_pressure_duration_1003h"] || 0).to_f,
    "low_pressure_duration_1007h" => (ws.metrics["low_pressure_duration_1007h"] || 0).to_f,
    "pressure_range_3h_awake" => (ws.metrics["pressure_range_3h_awake"] || 0).to_f,
    "pressure_jitter_3h_awake" => (ws.metrics["pressure_jitter_3h_awake"] || 0).to_f
  }
end

# SuggestionSnapshotの生成
# RuleEngineのmessageフォーマットを経由せず、Dentakuで条件式のみ評価する
def create_suggestion_snapshots(prefecture:, days:, verbose: false)
  env_rules = ::Suggestion::RuleRegistry.all.select { |r| r.category == "env" }
  rule_by_key = SuggestionRule.all.to_h { |r| [ r.key, r.id ] }
  calc = Dentaku::Calculator.new

  (0..days).each do |days_ago|
    date = Date.current - days_ago.days
    next if SuggestionSnapshot.exists?(date: date, prefecture_id: prefecture.id)

    ws = WeatherSnapshot.find_by(prefecture: prefecture, date: date)
    next unless ws

    ctx = build_weather_context(ws)

    matched_rules = env_rules.select do |rule|
      !!calc.evaluate!(rule.ast, ctx)
    rescue Dentaku::ParseError, Dentaku::ArgumentError
      false
    end

    records = matched_rules.filter_map do |rule|
      rule_id = rule_by_key[rule.key]
      next unless rule_id

      {
        date: date,
        prefecture_id: prefecture.id,
        rule_id: rule_id,
        metadata: ctx.dup,
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    SuggestionSnapshot.insert_all!(records) if records.any?
    puts "  Created #{records.size} suggestions for #{prefecture.name_ja} on #{date}" if verbose
  end
end

# ============================================================================
# Alice のサンプルデータ
# ============================================================================

alice = User.find_by!(email: "alice@example.com")
tokyo = Prefecture.find_by!(code: "13")

puts "Creating sample data for Alice (Tokyo)..."

# DailyLog（過去90日分）
create_sample_daily_logs(user: alice, prefecture: tokyo, days: sample_days, verbose: verbose)

# 今日のDailyLog（睡眠不足の固定値: 提案が多めに出るセットアップ）
DailyLog.find_or_create_by!(user: alice, date: Date.current) do |log|
  log.prefecture = tokyo
  log.sleep_hours = 5.5
  log.mood = 2
  log.fatigue = 4
  log.fatigue_level = 4
  log.note = "シード用テストデータ: 睡眠不足＋環境リスク高めの一日"
  log.self_score = 2
end

# WeatherSnapshot（過去90日分 + 今日）
create_weather_snapshots(prefecture: tokyo, days: sample_days, verbose: verbose)

# 今日のWeatherSnapshotを固定値で上書き（提案が多めに出る天気パターン）
today_ws = WeatherSnapshot.find_by!(prefecture: tokyo, date: Date.current)
today_ws.update!(metrics: {
  "temperature_c" => 36.0,
  "min_temperature_c" => 10.0,
  "humidity_pct" => 25.0,
  "pressure_hpa" => 975.0,
  "max_pressure_drop_1h_awake" => 0.0,
  "low_pressure_duration_1003h" => 3.0,
  "low_pressure_duration_1007h" => 0.0,
  "pressure_range_3h_awake" => 0.0,
  "pressure_jitter_3h_awake" => 0.0
})

# SuggestionSnapshot（過去90日分 + 今日）
create_suggestion_snapshots(prefecture: tokyo, days: sample_days, verbose: verbose)
puts "  Created weather/suggestion snapshots for Tokyo (#{sample_days} days)"

# DailyLogSuggestion + SuggestionFeedback（過去2週間分）
puts "Creating daily_log_suggestions for Alice..."
alice_suggestion_keys = %w[
  heatstroke_Warning heat_shock_Caution weather_pain_drop_Caution dryness_Warning
]
alice_rules_by_key = SuggestionRule.where(key: alice_suggestion_keys).index_by(&:key)
week_start = Date.current.beginning_of_week(:monday)
alice_target_dates = ((week_start - 7.days)..(week_start + 6.days)).to_a

alice_target_dates.each do |date|
  log = DailyLog.find_by(user: alice, date: date)
  next unless log

  keys_to_use = alice_suggestion_keys.sample(rand(1..3))
  keys_to_use.each_with_index do |rule_key, pos|
    rule = alice_rules_by_key[rule_key]
    next unless rule
    next if DailyLogSuggestion.exists?(daily_log_id: log.id, rule_id: rule.id)

    DailyLogSuggestion.create!(
      daily_log_id: log.id,
      suggestion_rule: rule,
      position: pos
    )

    # 約50%にフィードバックを付与
    next unless rand < 0.5

    SuggestionFeedback.find_or_create_by!(daily_log_id: log.id, suggestion_rule: rule) do |fb|
      fb.helpfulness = rand < 0.7
    end
  end
end
puts "  Created daily_log_suggestions for Alice (#{alice_target_dates.size} days)"

# ============================================================================
# Bob のサンプルデータ
# ============================================================================

bob = User.find_by!(email: "bob@example.com")
osaka = Prefecture.find_by!(code: "27")

puts "Creating sample data for Bob (Osaka)..."

# DailyLog（過去90日分）
create_sample_daily_logs(user: bob, prefecture: osaka, days: sample_days, verbose: verbose)

# WeatherSnapshot（過去90日分 + 今日）
create_weather_snapshots(prefecture: osaka, days: sample_days, verbose: verbose)

# SuggestionSnapshot（過去90日分 + 今日）
create_suggestion_snapshots(prefecture: osaka, days: sample_days, verbose: verbose)
puts "  Created weather/suggestion snapshots for Osaka (#{sample_days} days)"

# DailyLogSuggestion + SuggestionFeedback（過去2週間分、ルール4種）
puts "Creating daily_log_suggestions for Bob..."
bob_suggestion_keys = %w[
  heatstroke_Caution weather_pain_drop_Warning dryness_Caution cold_Warning
]
bob_rules_by_key = SuggestionRule.where(key: bob_suggestion_keys).index_by(&:key)
bob_target_dates = ((week_start - 7.days)..(week_start + 6.days)).to_a

bob_target_dates.each do |date|
  log = DailyLog.find_by(user: bob, date: date)
  next unless log

  keys_to_use = bob_suggestion_keys.sample(rand(1..3))
  keys_to_use.each_with_index do |rule_key, pos|
    rule = bob_rules_by_key[rule_key]
    next unless rule
    next if DailyLogSuggestion.exists?(daily_log_id: log.id, rule_id: rule.id)

    DailyLogSuggestion.create!(
      daily_log_id: log.id,
      suggestion_rule: rule,
      position: pos
    )

    # 約60%にフィードバックを付与
    next unless rand < 0.6

    SuggestionFeedback.find_or_create_by!(daily_log_id: log.id, suggestion_rule: rule) do |fb|
      fb.helpfulness = rand < 0.6
    end
  end
end
puts "  Created daily_log_suggestions for Bob (#{bob_target_dates.size} days)"

# ============================================================================
# PushSubscription ダミーデータ
# ============================================================================

puts "Creating dummy push subscriptions..."
[ alice, bob ].each do |user|
  endpoint = "https://example.com/push/#{user.name.downcase}"
  PushSubscription.find_or_create_by!(user: user, endpoint: endpoint) do |ps|
    ps.p256dh_key = "dummy_p256dh_key_for_#{user.name.downcase}"
    ps.auth_key = "dummy_auth_key_for_#{user.name.downcase}"
  end
  puts "  Created push subscription for #{user.name}"
end
