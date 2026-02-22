# frozen_string_literal: true

# ============================================================================
# 本番環境テストデータ投入・削除用Rakeタスク
#
# 使い方:
#   CONFIRM=yes rails test_seed:create
#   CONFIRM=yes rails test_seed:destroy
#
# 環境変数:
#   TEST_SEED_EMAIL    — テストユーザーのメールアドレス（デフォルト: climode.test@example.com）
#   TEST_SEED_PASSWORD — テストユーザーのパスワード（デフォルト: testpass123）
#   CONFIRM            — "yes" で確認プロンプトをスキップ
# ============================================================================

namespace :test_seed do
  TEST_EMAIL_DEFAULT = "climode.test@example.com"
  TEST_PASSWORD_DEFAULT = "testpass123"
  SAMPLE_DAYS = 30
  SPARSE_WEEK_OFFSET = 3 # 3週前をスパースウィークにする

  desc "テストユーザーとサンプルデータを投入する"
  task create: :environment do
    email = ENV.fetch("TEST_SEED_EMAIL", TEST_EMAIL_DEFAULT)
    password = ENV.fetch("TEST_SEED_PASSWORD", TEST_PASSWORD_DEFAULT)

    confirm!("テストユーザー（#{email}）とサンプルデータを投入します。続行しますか？")

    if User.exists?(email: email)
      puts "テストユーザー（#{email}）は既に存在します。スキップします。"
      next
    end

    ActiveRecord::Base.transaction do
      user = create_test_user!(email: email, password: password)
      register_concern_topics!(user)

      tokyo = Prefecture.find_by!(code: "13")
      daily_logs = create_daily_logs!(user: user, prefecture: tokyo)
      create_weather_snapshots!(prefecture: tokyo)
      create_suggestion_snapshots!(prefecture: tokyo)
      create_daily_log_suggestions!(daily_logs: daily_logs)
    end

    puts "\n✅ テストデータの投入が完了しました"
    puts "   メール: #{email}"
    puts "   パスワード: #{password}"
  end

  desc "テストユーザーと関連データを削除する"
  task destroy: :environment do
    email = ENV.fetch("TEST_SEED_EMAIL", TEST_EMAIL_DEFAULT)
    user = User.find_by(email: email)

    unless user
      puts "テストユーザー（#{email}）が見つかりません。"
      next
    end

    confirm!("テストユーザー（#{email}）と関連データを削除します。続行しますか？")

    counts = {}

    ActiveRecord::Base.transaction do
      daily_log_ids = user.daily_logs.pluck(:id)

      counts[:suggestion_feedbacks] = SuggestionFeedback.where(daily_log_id: daily_log_ids).delete_all
      counts[:daily_log_suggestions] = DailyLogSuggestion.where(daily_log_id: daily_log_ids).delete_all
      counts[:daily_logs] = user.daily_logs.delete_all
      counts[:user_concern_topics] = UserConcernTopic.where(user: user).delete_all
      counts[:push_subscriptions] = PushSubscription.where(user: user).delete_all
      counts[:user_identities] = UserIdentity.where(user: user).delete_all
      counts[:user] = user.destroy! ? 1 : 0
    end

    puts "\n✅ テストユーザーと関連データを削除しました"
    counts.each do |table, count|
      puts "   #{table}: #{count}件削除"
    end
    puts "   ※ WeatherSnapshot / SuggestionSnapshot は共有データのため削除していません"
  end

  # ============================================================================
  # Private helpers
  # ============================================================================

  def confirm!(message)
    return if ENV["CONFIRM"] == "yes"

    print "#{message} [y/N] "
    answer = $stdin.gets&.strip
    unless answer&.match?(/\Ay(es)?\z/i)
      puts "中断しました。"
      exit 0
    end
  end

  def create_test_user!(email:, password:)
    user = User.create!(
      name: "TestUser",
      email: email,
      password: password,
      password_confirmation: password,
      email_confirmed: true
    )
    user.update!(prefecture: Prefecture.find_by!(code: "13"))
    puts "👤 テストユーザーを作成しました: #{email}"
    user
  end

  def register_concern_topics!(user)
    ConcernTopic.find_each do |topic|
      UserConcernTopic.find_or_create_by!(user: user, concern_topic: topic)
    end
    puts "📋 関心トピックを#{ConcernTopic.count}件登録しました"
  end

  # --------------------------------------------------------------------------
  # DailyLog: 3パターン（体調不良・普通・体調良好）
  # --------------------------------------------------------------------------

  def daily_log_pattern(type)
    case type
    when :bad
      {
        sleep_hours: rand(40..55) / 10.0,
        mood: rand(1..2),
        fatigue: rand(4..5),
        self_score: 1
      }
    when :normal
      {
        sleep_hours: rand(60..75) / 10.0,
        mood: 3,
        fatigue: rand(2..3),
        self_score: 2
      }
    when :good
      {
        sleep_hours: rand(75..90) / 10.0,
        mood: rand(4..5),
        fatigue: rand(1..2),
        self_score: 3
      }
    end
  end

  def pattern_for_day(days_ago)
    # スパースウィーク（3週前）はほぼスキップ
    sparse_week_start = SPARSE_WEEK_OFFSET * 7
    if days_ago.between?(sparse_week_start, sparse_week_start + 6)
      return :skip unless days_ago == sparse_week_start || days_ago == sparse_week_start + 3
    end

    # 体調不良30%、普通50%、体調良好20%
    r = (days_ago * 7 + 3) % 10 # 決定論的な分布
    if r < 3
      :bad
    elsif r < 8
      :normal
    else
      :good
    end
  end

  def note_for_pattern(type)
    case type
    when :bad then "体調が優れない日です。疲労感が強く、十分に休息を取りたいです。"
    when :normal then "普通の一日でした。特に問題なし。"
    when :good then "体調が良く、充実した一日でした。疲れも少なく快調です。"
    end
  end

  def create_daily_logs!(user:, prefecture:)
    logs = {}

    # 当日: 体調不良の固定値
    today_log = DailyLog.create!(
      user: user,
      prefecture: prefecture,
      date: Date.current,
      sleep_hours: 4.5,
      mood: 1,
      fatigue: 5,
      fatigue_level: 5,
      note: "テストデータ: 睡眠不足＋環境リスク高めの一日",
      self_score: 1
    )
    logs[Date.current] = { log: today_log, type: :bad }

    # 過去30日分
    (1..SAMPLE_DAYS).each do |days_ago|
      date = Date.current - days_ago.days
      type = pattern_for_day(days_ago)
      next if type == :skip

      attrs = daily_log_pattern(type)
      log = DailyLog.create!(
        user: user,
        prefecture: prefecture,
        date: date,
        sleep_hours: attrs[:sleep_hours],
        mood: attrs[:mood],
        fatigue: attrs[:fatigue],
        fatigue_level: attrs[:fatigue],
        note: note_for_pattern(type),
        self_score: attrs[:self_score]
      )
      logs[date] = { log: log, type: type }
    end

    puts "📊 DailyLogを#{logs.size}件作成しました（スパースウィーク含む）"
    logs
  end

  # --------------------------------------------------------------------------
  # WeatherSnapshot: 4パターン（低気圧・高温・乾燥・通常）
  # --------------------------------------------------------------------------

  def weather_pattern(type)
    case type
    when :low_pressure
      {
        "temperature_c" => rand(150..220) / 10.0,
        "min_temperature_c" => rand(80..140) / 10.0,
        "humidity_pct" => rand(500..700) / 10.0,
        "pressure_hpa" => rand(9800..10040) / 10.0,
        "max_pressure_drop_1h_awake" => rand(10..30) / 10.0,
        "low_pressure_duration_1003h" => rand(20..60) / 10.0,
        "low_pressure_duration_1007h" => rand(10..40) / 10.0,
        "pressure_range_3h_awake" => rand(20..50) / 10.0,
        "pressure_jitter_3h_awake" => rand(10..30) / 10.0
      }
    when :high_temp
      {
        "temperature_c" => rand(340..380) / 10.0,
        "min_temperature_c" => rand(260..300) / 10.0,
        "humidity_pct" => rand(600..800) / 10.0,
        "pressure_hpa" => rand(10100..10180) / 10.0,
        "max_pressure_drop_1h_awake" => rand(0..5) / 10.0,
        "low_pressure_duration_1003h" => 0.0,
        "low_pressure_duration_1007h" => 0.0,
        "pressure_range_3h_awake" => rand(0..20) / 10.0,
        "pressure_jitter_3h_awake" => rand(0..10) / 10.0
      }
    when :dry
      {
        "temperature_c" => rand(100..200) / 10.0,
        "min_temperature_c" => rand(30..100) / 10.0,
        "humidity_pct" => rand(150..280) / 10.0,
        "pressure_hpa" => rand(10150..10200) / 10.0,
        "max_pressure_drop_1h_awake" => rand(0..5) / 10.0,
        "low_pressure_duration_1003h" => 0.0,
        "low_pressure_duration_1007h" => 0.0,
        "pressure_range_3h_awake" => rand(0..15) / 10.0,
        "pressure_jitter_3h_awake" => rand(0..10) / 10.0
      }
    when :calm
      {
        "temperature_c" => rand(180..250) / 10.0,
        "min_temperature_c" => rand(120..170) / 10.0,
        "humidity_pct" => rand(400..600) / 10.0,
        "pressure_hpa" => rand(10130..10170) / 10.0,
        "max_pressure_drop_1h_awake" => rand(0..3) / 10.0,
        "low_pressure_duration_1003h" => 0.0,
        "low_pressure_duration_1007h" => 0.0,
        "pressure_range_3h_awake" => rand(0..10) / 10.0,
        "pressure_jitter_3h_awake" => rand(0..5) / 10.0
      }
    end
  end

  def weather_type_for_day(days_ago)
    # 約25%ずつの決定論的分布
    r = days_ago % 4
    %i[low_pressure high_temp dry calm][r]
  end

  def create_weather_snapshots!(prefecture:)
    count = 0

    # 当日: 低気圧＋高温の固定値（提案が多く出るパターン）
    WeatherSnapshot.find_or_create_by!(prefecture: prefecture, date: Date.current) do |ws|
      ws.metrics = {
        "temperature_c" => 36.0,
        "min_temperature_c" => 10.0,
        "humidity_pct" => 25.0,
        "pressure_hpa" => 975.0,
        "max_pressure_drop_1h_awake" => 2.5,
        "low_pressure_duration_1003h" => 4.0,
        "low_pressure_duration_1007h" => 2.0,
        "pressure_range_3h_awake" => 3.0,
        "pressure_jitter_3h_awake" => 1.5
      }
      count += 1
    end

    # 過去30日分
    (1..SAMPLE_DAYS).each do |days_ago|
      date = Date.current - days_ago.days
      type = weather_type_for_day(days_ago)
      WeatherSnapshot.find_or_create_by!(prefecture: prefecture, date: date) do |ws|
        ws.metrics = weather_pattern(type)
        count += 1
      end
    end

    puts "🌤️  WeatherSnapshotを#{count}件作成しました"
  end

  # --------------------------------------------------------------------------
  # SuggestionSnapshot: ルール評価
  # --------------------------------------------------------------------------

  def create_suggestion_snapshots!(prefecture:)
    env_rules = ::Suggestion::RuleRegistry.all.select { |r| r.category == "env" }
    rule_by_key = SuggestionRule.all.to_h { |r| [ r.key, r.id ] }
    calc = Dentaku::Calculator.new
    total = 0

    (0..SAMPLE_DAYS).each do |days_ago|
      date = Date.current - days_ago.days
      next if SuggestionSnapshot.exists?(date: date, prefecture_id: prefecture.id)

      ws = WeatherSnapshot.find_by(prefecture: prefecture, date: date)
      next unless ws

      ctx = {
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

      if records.any?
        SuggestionSnapshot.insert_all!(records)
        total += records.size
      end
    end

    puts "💡 SuggestionSnapshotを#{total}件作成しました"
  end

  # --------------------------------------------------------------------------
  # DailyLogSuggestion / SuggestionFeedback
  # --------------------------------------------------------------------------

  def create_daily_log_suggestions!(daily_logs:)
    suggestion_keys = SuggestionRule.where(category: "env").pluck(:key)
    rules_by_key = SuggestionRule.where(key: suggestion_keys).index_by(&:key)
    dls_count = 0
    fb_count = 0

    # 過去2週間 + 当日
    target_dates = daily_logs.keys.select { |d| d >= Date.current - 14.days }

    target_dates.each do |date|
      entry = daily_logs[date]
      next unless entry

      log = entry[:log]
      type = entry[:type]

      # 体調良好 + 通常天気の日にはシグナルを紐づけない
      ws = WeatherSnapshot.find_by(prefecture: log.prefecture, date: date)
      if type == :good && ws && calm_weather?(ws)
        next
      end

      # 当日は最低2件、それ以外は1〜3件
      num = date == Date.current ? rand(2..3) : rand(1..3)
      selected_keys = suggestion_keys.sample(num)

      selected_keys.each_with_index do |key, pos|
        rule = rules_by_key[key]
        next unless rule
        next if DailyLogSuggestion.exists?(daily_log_id: log.id, rule_id: rule.id)

        DailyLogSuggestion.create!(
          daily_log_id: log.id,
          suggestion_rule: rule,
          position: pos
        )
        dls_count += 1

        # 約50%にフィードバック（70%がhelpful）
        next unless rand < 0.5

        SuggestionFeedback.find_or_create_by!(daily_log_id: log.id, suggestion_rule: rule) do |fb|
          fb.helpfulness = rand < 0.7
        end
        fb_count += 1
      end
    end

    puts "🔔 DailyLogSuggestionを#{dls_count}件作成しました"
    puts "📝 SuggestionFeedbackを#{fb_count}件作成しました"
  end

  def calm_weather?(ws)
    metrics = ws.metrics
    temp = (metrics["temperature_c"] || 0).to_f
    humidity = (metrics["humidity_pct"] || 0).to_f
    pressure = (metrics["pressure_hpa"] || 0).to_f
    drop = (metrics["max_pressure_drop_1h_awake"] || 0).to_f

    temp.between?(15.0, 30.0) && humidity.between?(35.0, 65.0) && pressure >= 1010.0 && drop < 1.0
  end
end
