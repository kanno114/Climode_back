FactoryBot.define do
  factory :daily_log_suggestion do
    association :daily_log
    suggestion_rule { SuggestionRule.find_by!(key: "pressure_drop_signal_warning") }
    position { 0 }
  end
end
