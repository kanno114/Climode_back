FactoryBot.define do
  factory :user_concern_topic do
    association :user
    association :concern_topic
  end
end
