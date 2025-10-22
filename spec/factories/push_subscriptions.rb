FactoryBot.define do
  factory :push_subscription do
    association :user
    endpoint { Faker::Internet.url }
    p256dh_key { Faker::Alphanumeric.alpha(number: 88) }
    auth_key { Faker::Alphanumeric.alpha(number: 24) }
  end
end
