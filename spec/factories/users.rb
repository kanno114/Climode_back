FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    name { Faker::Name.name }
    association :prefecture

    trait :with_image do
      image { "https://example.com/avatar.jpg" }
    end

    trait :without_prefecture do
      prefecture { nil }
    end
  end
end
