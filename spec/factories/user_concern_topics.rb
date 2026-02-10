FactoryBot.define do
  factory :user_concern_topic do
    association :user
    concern_topic_key { "heatstroke" }
  end
end
