# frozen_string_literal: true

require "rails_helper"

RSpec.describe SuggestionRule do
  describe ".enabled" do
    it "enabledがtrueのルールのみ返す" do
      enabled_rule = SuggestionRule.find_by(key: "heatstroke_Danger")
      disabled_rule = SuggestionRule.create!(
        key: "disabled_test_rule",
        title: "無効ルール",
        message: "テスト",
        tags: [],
        severity: 50,
        category: "env",
        concerns: [],
        condition: "temperature_c > 100",
        enabled: false
      )

      result = described_class.enabled
      expect(result).to include(enabled_rule)
      expect(result).not_to include(disabled_rule)
    ensure
      disabled_rule&.destroy
    end
  end
end
