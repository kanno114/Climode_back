FactoryBot.define do
  factory :user_identity do
    association :user
    provider { "google" }
    sequence(:uid) { |n| "uid_#{n}" }
    email { Faker::Internet.email }
    display_name { Faker::Name.name }

    trait :google do
      provider { "google" }
    end

    trait :github do
      provider { "github" }
    end

    trait :facebook do
      provider { "facebook" }
    end
  end
end
