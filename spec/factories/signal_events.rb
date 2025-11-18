FactoryBot.define do
  factory :signal_event do
    association :user
    trigger_key { "pressure_drop" }
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
      trigger_key { "sleep_shortage" }
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

