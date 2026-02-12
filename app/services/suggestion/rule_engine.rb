 # frozen_string_literal: true

 module Suggestion
   # 汎用ルール評価エンジン
   #
   # - 与えられた rules（RuleRegistryのRule配列）と context（Hash）を元に
   #   Dentaku で条件式を評価し、Suggestion構造体の配列を返す
   # - どのコンテキストビルダー（ユーザー+DailyLog / 都道府県+WeatherSnapshotなど）からも再利用できる
   class RuleEngine
     Suggestion = Suggestion::SuggestionEngine::Suggestion

    def self.call(rules:, context:, limit: nil, tag_diversity: true)
      new(rules: rules, context: context, limit: limit, tag_diversity: tag_diversity).call
    end

     def initialize(rules:, context:, limit:, tag_diversity:)
       @rules = rules
       @context = context
       @limit = limit
       @tag_diversity = tag_diversity
     end

    def call
      candidates = @rules.filter_map { |rule| evaluate(rule, @context) }
      self.class.pick_top(candidates, limit: @limit, tag_diversity: @tag_diversity)
    end

    # 同groupの連発抑制＋severity優先。SuggestionEngine からも利用可能
    def self.pick_top(list, limit: nil, tag_diversity: true)
      sorted = list.sort_by { |s| -s.severity }
      return sorted.first(limit) if limit && !tag_diversity

      picked = []
      used_groups = Set.new

      sorted.each do |s|
        group = s.group.to_s
        if group.present? && used_groups.include?(group) && picked.size >= 1
          next
        end

        picked << s
        used_groups.add(group) if group.present?
        break if limit && picked.size >= limit
      end

      picked
    end

    private

    def evaluate(rule, ctx)
       calc = Dentaku::Calculator.new

       ok = !!calc.evaluate!(rule.ast, ctx)
       return nil unless ok

       Suggestion.new(
         key:          rule.key,
         title:        rule.title,
         message:      rule.message % ctx.symbolize_keys,
         tags:         rule.tags,
         severity:     rule.severity,
         triggers:     extract_triggers(rule.raw_condition, ctx),
         category:     rule.category,
         concerns:     rule.concerns,
         reason_text:  rule.reason_text,
         evidence_text: rule.evidence_text,
         group:        rule.group,
         level:        rule.level
       )
     rescue Dentaku::ParseError, Dentaku::ArgumentError
       nil
     end

    # 条件式に含まれる識別子を拾って、実際の値を付ける。suggestion_snapshots の triggers 構築にも利用
    def self.extract_triggers(condition_str, ctx)
      ctx = ctx.stringify_keys if ctx.keys.first.is_a?(Symbol)
      keys = condition_str.scan(/[a-zA-Z_]\w*/).uniq
      keys.grep_v(/\A(?:AND|OR|NOT|TRUE|FALSE)\z/i)
          .select { |k| ctx.key?(k) }
          .to_h { |k| [ k, ctx[k] ] }
    end

    def extract_triggers(condition_str, ctx)
      self.class.extract_triggers(condition_str, ctx)
    end
   end
 end
