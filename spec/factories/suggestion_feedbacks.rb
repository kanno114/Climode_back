FactoryBot.define do
  factory :suggestion_feedback do
    association :daily_log
    suggestion_rule { SuggestionRule.find_by!(key: "pressure_drop_signal_warning") }
    helpfulness { true }

    trait :not_helpful do
      helpfulness { false }
    end
  end
end
