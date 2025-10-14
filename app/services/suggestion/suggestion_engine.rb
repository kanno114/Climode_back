# frozen_string_literal: true

module Suggestion
  class SuggestionEngine
    Suggestion = Struct.new(:key, :title, :message, :tags, :severity, :triggers, keyword_init: true)

    def self.call(user:, date: Date.current)
      new(user: user, date: date).call
    end

    def initialize(user:, date:)
      @user = user
      @date = date
      @daily_log = DailyLog.find_by!(user_id: @user.id, date: @date)
      @weather = @daily_log.weather_observation
      @rules = RuleRegistry.all
    end

    def call
      return [] if @daily_log.nil?

      ctx = build_context
      candidates = @rules.filter_map { |rule| evaluate(rule, ctx) }

      # 同タグ連発を抑えつつ severity で上位採用（最大3件）
      pick_diverse_top(candidates, limit: 3)
    end

    private

    # --- 入力文脈を構築 ---
    def build_context
      {
        "sleep_hours"       => (@daily_log.sleep_hours || 0).to_f,
        "mood"              => @daily_log.mood.to_i,
        "score"             => @daily_log.score,
        "temperature_c"     => @weather.temperature_c.to_f,
        "humidity_pct"      => @weather.humidity_pct.to_f,
        "pressure_hpa"      => @weather.pressure_hpa.to_f
      }
    end

    # --- Dentakuで安全評価 ---
    def evaluate(rule, ctx)
      calc = Dentaku::Calculator.new

      ok = !!calc.evaluate!(rule.ast, ctx)
      return nil unless ok

      Suggestion.new(
        key: rule.key,
        title: rule.title,
        message: rule.message % ctx.symbolize_keys,
        tags: rule.tags,
        severity: rule.severity,
        triggers: extract_triggers(rule.raw_condition, ctx)
      )
    rescue Dentaku::ParseError, Dentaku::ArgumentError
      nil
    end

    # 条件式に含まれる識別子を拾って、実際の値を付ける
    def extract_triggers(condition_str, ctx)
      keys = condition_str.scan(/[a-zA-Z_]\w*/).uniq
      keys.grep_v(/\A(?:AND|OR|NOT|TRUE|FALSE)\z/i)
          .select { |k| ctx.key?(k) }
          .to_h { |k| [ k, ctx[k] ] }
    end

    # 同タグの連発抑制＋severity優先
    def pick_diverse_top(list, limit:)
      picked = []
      used_tags = Set.new
      list.sort_by { |s| -s.severity }.each do |s|
        next if (s.tags & used_tags.to_a).any? && picked.size >= 1
        picked << s
        used_tags.merge(s.tags)
        break if picked.size >= limit
      end
      picked
    end
  end
end
