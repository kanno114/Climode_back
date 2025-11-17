FactoryBot.define do
  factory :trigger do
    sequence(:key) { |n| "trigger_key_#{n}" }
    sequence(:label) { |n| "トリガー#{n}" }
    category { "env" }
    is_active { true }
    version { 1 }
    rule do
      {
        "metric" => "pressure_drop_6h",
        "operator" => "lte",
        "levels" => [
          { "id" => "attention", "label" => "注意", "threshold" => -3.0, "priority" => 50 }
        ]
      }
    end

    trait :body do
      category { "body" }
    end

    trait :inactive do
      is_active { false }
    end
  end
end
