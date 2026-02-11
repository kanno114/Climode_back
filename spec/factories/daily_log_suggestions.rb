FactoryBot.define do
  factory :daily_log_suggestion do
    association :daily_log
    suggestion_key { "pressure_drop_signal_warning" }
    title { "気圧変動に注意" }
    message { "気圧が急変動しています。体調に気をつけてください。" }
    tags { %w[weather pressure] }
    severity { 2 }
    category { "weather" }
    position { 0 }
  end
end
