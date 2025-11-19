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
      @weather_snapshot = WeatherSnapshot.find_by(
        prefecture: @daily_log.prefecture,
        date: @date
      )
      @signal_events = SignalEvent.for_user(@user).for_date(@date)
      @rules = ::Suggestion::RuleRegistry.all
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
      metrics = @weather_snapshot&.metrics || {}
      ctx = {
        "sleep_hours"       => (@daily_log.sleep_hours || 0).to_f,
        "mood"              => @daily_log.mood.to_i,
        "score"             => @daily_log.score,
        "temperature_c"     => (metrics["temperature_c"] || 0).to_f,
        "humidity_pct"      => (metrics["humidity_pct"] || 0).to_f,
        "pressure_hpa"      => (metrics["pressure_hpa"] || 0).to_f
      }

      # SignalEvent情報を追加
      add_signal_events_to_context(ctx)
      ctx
    end

    # SignalEvent情報をコンテキストに追加
    # よく使われるトリガーキーに対してデフォルト値を設定
    def add_signal_events_to_context(ctx)
      # よく使われるトリガーキーのリスト（Trigger定義に合わせて拡張）
      common_trigger_keys = [ "pressure_drop", "sleep_shortage", "humidity_high", "temperature_drop" ]

      # デフォルト値を設定（SignalEventが存在しない場合）
      common_trigger_keys.each do |trigger_key|
        ctx["has_#{trigger_key}_signal"] = false
        ctx["#{trigger_key}_level"] = 0
        ctx["#{trigger_key}_priority"] = 0.0
        ctx["#{trigger_key}_category"] = 0
      end

      # 実際のSignalEventの値を上書き
      @signal_events.each do |signal|
        trigger_key = signal.trigger_key
        # シグナルの存在フラグ
        ctx["has_#{trigger_key}_signal"] = true
        # シグナルのレベル（文字列を数値に変換: attention=1, warning=2, strong=3）
        level_value = case signal.level
        when "attention" then 1
        when "warning" then 2
        when "strong" then 3
        else 0
        end
        ctx["#{trigger_key}_level"] = level_value
        # シグナルの優先度
        ctx["#{trigger_key}_priority"] = signal.priority.to_f
        # シグナルのカテゴリ（env=1, body=2）
        category_value = signal.category == "env" ? 1 : 2
        ctx["#{trigger_key}_category"] = category_value
      end
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
