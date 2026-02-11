# frozen_string_literal: true

module Suggestion
  class SuggestionEngine
    GENERAL_CONCERN_KEY = "general".freeze

    Suggestion = Struct.new(:key, :title, :message, :tags, :severity, :triggers, :category, :concerns, keyword_init: true)

    def self.call(user:, date: Date.current, daily_log: nil)
      new(user: user, date: date, daily_log: daily_log).call
    end

    def initialize(user:, date:, daily_log: nil)
      @user = user
      @date = date
      @daily_log = daily_log || DailyLog.find_by!(user_id: @user.id, date: @date)
      @weather_snapshot = WeatherSnapshot.find_by(
        prefecture: @daily_log.prefecture,
        date: @date
      )
      @rules = filter_rules_by_user_concerns
    end

    def call
      return [] if @daily_log.nil?

      env_suggestions = fetch_env_suggestions_from_snapshots

      if env_suggestions.nil?
        # フォールバック: suggestion_snapshots が空（7:30 前など）
        fallback_to_rule_engine
      else
        body_suggestions = fetch_body_suggestions
        candidates = env_suggestions + body_suggestions
        RuleEngine.pick_top(candidates, limit: 3, tag_diversity: true)
      end
    end

    private

    # suggestion_snapshots から env 分を取得。空の場合は nil を返す（フォールバック用）
    def fetch_env_suggestions_from_snapshots
      snapshots = SuggestionSnapshot.where(
        date: @date,
        prefecture_id: @daily_log.prefecture_id
      )

      return nil if snapshots.empty?

      allowed_rule_keys = @rules.select { |r| r.category == "env" }.map(&:key).to_set
      registry_by_key = ::Suggestion::RuleRegistry.all.to_h { |r| [ r.key, r ] }

      snapshots
        .select { |s| allowed_rule_keys.include?(s.rule_key) }
        .map do |s|
          rule = registry_by_key[s.rule_key]
          metadata = (s.metadata || {}).stringify_keys
          triggers = rule ? RuleEngine.extract_triggers(rule.raw_condition, metadata) : metadata

          Suggestion.new(
            key: s.rule_key,
            title: s.title,
            message: s.message.to_s,
            tags: Array(s.tags),
            severity: s.severity,
            triggers: triggers,
            category: s.category,
            concerns: rule&.concerns || []
          )
        end
    end

    # body ルールのみ RuleEngine で生成
    def fetch_body_suggestions
      body_rules = @rules.select { |r| r.category == "body" }
      return [] if body_rules.empty?

      ctx = build_context
      ::Suggestion::RuleEngine.call(
        rules: body_rules,
        context: ctx,
        limit: 10,
        tag_diversity: false
      )
    end

    def fallback_to_rule_engine
      ctx = build_context
      ::Suggestion::RuleEngine.call(rules: @rules, context: ctx, limit: 3, tag_diversity: true)
    end

    # --- 入力文脈を構築 ---
    def build_context
      metrics = @weather_snapshot&.metrics || {}
      ctx = {
        "sleep_hours"       => (@daily_log.sleep_hours || 0).to_f,
        "mood"              => @daily_log.mood.to_i,
        "temperature_c"     => (metrics["temperature_c"] || 0).to_f,
        "min_temperature_c" => (metrics["min_temperature_c"] || 0).to_f,
        "humidity_pct"      => (metrics["humidity_pct"] || 0).to_f,
        "pressure_hpa"      => (metrics["pressure_hpa"] || 0).to_f,
        # 気象病・天気痛向けの気圧差メトリクス
        "max_pressure_drop_1h_awake"   => (metrics["max_pressure_drop_1h_awake"] || 0).to_f,
        "low_pressure_duration_1003h"  => (metrics["low_pressure_duration_1003h"] || 0).to_f,
        "low_pressure_duration_1007h"  => (metrics["low_pressure_duration_1007h"] || 0).to_f,
        "pressure_range_3h_awake"      => (metrics["pressure_range_3h_awake"] || 0).to_f,
        "pressure_jitter_3h_awake"     => (metrics["pressure_jitter_3h_awake"] || 0).to_f
      }
      ctx
    end

    def filter_rules_by_user_concerns
      all_rules = ::Suggestion::RuleRegistry.all
      user_concern_keys = @user.concern_topics.pluck(:key).to_set

      if user_concern_keys.empty?
        all_rules.select { |r| r.concerns.include?(GENERAL_CONCERN_KEY) }
      else
        all_rules.select do |r|
          r.concerns.include?(GENERAL_CONCERN_KEY) || (r.concerns.to_set & user_concern_keys).any?
        end
      end
    end
  end
end
