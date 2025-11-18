FactoryBot.define do
  factory :signal_event do
    association :user
    sequence(:trigger_key) { |n| "trigger_key_#{n}" }
    category { "env" }
    level { "strong" }
    priority { 80 }
    evaluated_at { Time.current }
    meta do
      {
        "observed" => -6.4,
        "threshold" => -6.0,
        "metric" => "pressure_drop_6h",
        "operator" => "lte"
      }
    end

    trait :body do
      category { "body" }
      sequence(:trigger_key) { |n| "sleep_shortage_#{n}" }
      level { "attention" }
      priority { 35 }
      meta do
        {
          "observed" => 5.5,
          "threshold" => 6.0,
          "metric" => "sleep_hours",
          "operator" => "lte"
        }
      end
    end
  end
end
