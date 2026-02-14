# frozen_string_literal: true

# テスト用 suggestion_rules を health_rules.yml から投入。spec で使う追加ルールも作成
RSpec.configure do |config|
  config.before(:suite) do
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
    end

    # spec で使用する追加ルール（health_rules.yml にないもの）
    [
      { key: "pressure_drop_signal_warning", title: "気圧変動に注意", message: "気圧が急変動しています。", condition: "max_pressure_drop_1h_awake <= -3.0", category: "env" },
      { key: "low_mood", title: "気分が低い", message: "気分が落ち込んでいます。", condition: "mood < 3", category: "env" },
      { key: "test_suggestion", title: "テスト提案1", message: "メッセージ1", condition: "temperature_c > 0", category: "env" },
      { key: "test_suggestion2", title: "テスト提案2", message: "メッセージ2", condition: "temperature_c > 0", category: "weather" }
    ].each do |attrs|
      SuggestionRule.find_or_create_by!(key: attrs[:key]) do |r|
        r.title = attrs[:title]
        r.message = attrs[:message]
        r.condition = attrs[:condition]
        r.tags = []
        r.severity = 70
        r.category = attrs[:category] || "env"
        r.concerns = []
      end
    end
  end
end
