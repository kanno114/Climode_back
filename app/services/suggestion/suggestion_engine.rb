# frozen_string_literal: true

module Suggestion
  class SuggestionEngine
    GENERAL_CONCERN_KEY = "general".freeze

    Suggestion = Struct.new(:key, :title, :message, :tags, :severity, :triggers, :category, :concerns, keyword_init: true)

    def self.call(user:, date: Date.current)
      new(user: user, date: date).call
    end

    def initialize(user:, date:)
      @user = user
      @date = date
      @daily_log = DailyLog.find_by!(user_id: @user.id, date: @date)
      @weather_snapshot = WeatherSnapshot.find_by(
        prefecture: @daily_log.prefecture,
        date: @date
      )
      @rules = filter_rules_by_user_concerns
    end

    def call
      return [] if @daily_log.nil?

      ctx = build_context
      ::Suggestion::RuleEngine.call(rules: @rules, context: ctx, limit: 3, tag_diversity: true)
    end

    private

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
      user_concern_keys = UserConcernTopic.where(user: @user).pluck(:concern_topic_key).to_set

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
