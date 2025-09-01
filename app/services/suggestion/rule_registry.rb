# frozen_string_literal: true
module Suggestion
  class RuleRegistry
    Rule = Struct.new(:key, :ast, :raw_condition, :title, :message, :tags, :severity, keyword_init: true)

    class << self
      def all
        @rules ||= load!
      end

      def reload!
        @rules = load!
      end

      private

      def load!
        calc = Dentaku::Calculator.new
        raw = YAML.load_file(Rails.root.join("config/health_rules.yml"))["rules"]
        raw.map do |r|
          expr = normalize_expr(r["condition"].to_s)
          ast  = calc.ast(expr) # パースしてAST化（ここで文法エラー検出）
          Rule.new(
            key:        r.fetch("key"),
            ast:        ast,
            raw_condition: r["condition"].to_s,
            title:      r.fetch("title"),
            message:    r.fetch("message"),
            tags:       Array(r["tags"]),
            severity:   r.fetch("severity").to_i
          )
        end
      end

      # YAMLをそのまま使えるよう最小正規化（AND/OR/真偽値）
      def normalize_expr(expr)
        expr
          .gsub('&&', ' AND ')
          .gsub('||', ' OR ')
          .gsub(/\btrue\b/i, 'TRUE')
          .gsub(/\bfalse\b/i, 'FALSE')
      end
    end
  end
end
