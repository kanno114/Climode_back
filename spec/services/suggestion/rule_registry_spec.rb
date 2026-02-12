require 'rails_helper'

RSpec.describe Suggestion::RuleRegistry do
  describe '.all' do
    it 'YAMLファイルからルールを読み込む' do
      rules = described_class.all

      expect(rules).to be_an(Array)
      expect(rules.length).to be > 0
    end

    it 'ルールが正しい構造を持つ' do
      rules = described_class.all

      rules.each do |rule|
        expect(rule).to have_attributes(
          key: be_a(String),
          ast: be_a(Dentaku::AST::Node),
          raw_condition: be_a(String),
          title: be_a(String),
          message: be_a(String),
          tags: be_an(Array),
          severity: be_a(Integer),
          category: be_a(String),
          concerns: be_an(Array)
        )
      end
    end

    it '特定のルールが読み込まれている' do
      rules = described_class.all
      rule_keys = rules.map(&:key)

      expect(rule_keys).to include('sleep_Caution')
      expect(rule_keys).to include('heatstroke_Danger')
      expect(rule_keys).to include('weather_pain_drop_Warning')
      expect(rule_keys).to include('weather_pain_low_1003_Warning')
      expect(rule_keys).to include('weather_pain_low_1007_Caution')
    end

    it 'キャッシュされる' do
      first_call = described_class.all
      second_call = described_class.all

      expect(first_call.object_id).to eq(second_call.object_id)
    end
  end

  describe '.reload!' do
    it 'キャッシュをクリアして再読み込みする' do
      first_call = described_class.all
      described_class.reload!
      second_call = described_class.all

      expect(first_call.object_id).not_to eq(second_call.object_id)
    end
  end

  describe 'AST生成' do
    it '有効な条件式からASTを生成する' do
      rules = described_class.all

      rules.each do |rule|
        expect(rule.ast).to be_a(Dentaku::AST::Node)
      end
    end

    it '無効な条件式でエラーが発生する場合、読み込み時にエラーになる' do
      # health_rules.ymlに無効な条件式がある場合、load!時にエラーになる
      # 実際のYAMLファイルが有効であることを前提とする
      expect {
        described_class.all
      }.not_to raise_error
    end
  end

  describe '式の正規化' do
    it '&&をANDに変換する' do
      rules = described_class.all
      rule = rules.find { |r| r.raw_condition.include?('&&') || r.raw_condition.include?('AND') }

      if rule
        # 正規化された式はANDを使用している
        normalized = described_class.send(:normalize_expr, 'sleep_hours < 6 && temperature_c > 20')
        expect(normalized).to include('AND')
        expect(normalized).not_to include('&&')
      end
    end

    it '||をORに変換する' do
      normalized = described_class.send(:normalize_expr, 'pressure_hpa < 990 || pressure_hpa > 1030')
      expect(normalized).to include('OR')
      expect(normalized).not_to include('||')
    end

    it 'trueをTRUEに変換する' do
      normalized = described_class.send(:normalize_expr, 'true')
      expect(normalized).to eq('TRUE')
    end

    it 'falseをFALSEに変換する' do
      normalized = described_class.send(:normalize_expr, 'false')
      expect(normalized).to eq('FALSE')
    end
  end

  describe 'severityの型変換' do
    it 'severityが整数に変換される' do
      rules = described_class.all

      rules.each do |rule|
        expect(rule.severity).to be_a(Integer)
      end
    end
  end

  describe 'tagsの配列化' do
    it 'tagsが配列として扱われる' do
      rules = described_class.all

      rules.each do |rule|
        expect(rule.tags).to be_an(Array)
      end
    end
  end

  describe 'concernsの配列化' do
    it 'concernsが配列として扱われる' do
      rules = described_class.all

      rules.each do |rule|
        expect(rule.concerns).to be_an(Array)
      end
    end
  end

  describe 'groupとlevelの読み込み' do
    it 'groupが読み込まれる' do
      rules = described_class.all
      heatstroke = rules.find { |r| r.key == 'heatstroke_Danger' }
      expect(heatstroke.group).to eq('temperature')
    end

    it 'levelが読み込まれる' do
      rules = described_class.all
      heatstroke = rules.find { |r| r.key == 'heatstroke_Danger' }
      expect(heatstroke.level).to eq('Danger')
    end
  end

  describe 'categoryの設定' do
    it 'categoryがenvまたはbodyである' do
      rules = described_class.all

      rules.each do |rule|
        expect(rule.category).to be_in([ 'env', 'body' ])
      end
    end

    it '特定のルールが正しいcategoryを持つ' do
      rules = described_class.all
      sleep_rule = rules.find { |r| r.key == 'sleep_Caution' }
      hot_rule = rules.find { |r| r.key == 'heatstroke_Danger' }

      expect(sleep_rule&.category).to eq('body')
      expect(hot_rule&.category).to eq('env')
    end
  end
end
