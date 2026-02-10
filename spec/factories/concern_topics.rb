FactoryBot.define do
  factory :concern_topic do
    sequence(:key) { |n| "topic_#{n}" }
    label_ja { "関心テーマ#{key}" }
    description_ja { "説明: #{key}" }
    rule_concerns { [ key ] }
    position { 1 }
    active { true }
  end
end
