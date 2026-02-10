 # frozen_string_literal: true

 module Suggestion
   # 汎用ルール評価エンジン
   #
   # - 与えられた rules（RuleRegistryのRule配列）と context（Hash）を元に
   #   Dentaku で条件式を評価し、Suggestion構造体の配列を返す
   # - どのコンテキストビルダー（ユーザー+DailyLog / 都道府県+WeatherSnapshotなど）からも再利用できる
   class RuleEngine
     Suggestion = Suggestion::SuggestionEngine::Suggestion

     def self.call(rules:, context:, limit: 3, tag_diversity: true)
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
       pick_top(candidates, limit: @limit, tag_diversity: @tag_diversity)
     end

     private

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
         triggers: extract_triggers(rule.raw_condition, ctx),
        category: rule.category,
        concerns: rule.concerns
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
     def pick_top(list, limit:, tag_diversity:)
       return list.sort_by { |s| -s.severity }.first(limit) unless tag_diversity

       picked = []
       used_tags = Set.new

       list.sort_by { |s| -s.severity }.each do |s|
         if (s.tags & used_tags.to_a).any? && picked.size >= 1
           next
         end

         picked << s
         used_tags.merge(s.tags)
         break if picked.size >= limit
       end

       picked
     end
   end
 end
