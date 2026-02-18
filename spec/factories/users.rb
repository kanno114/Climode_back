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

    trait :oauth do
      transient do
        oauth_password { SecureRandom.urlsafe_base64(16) }
      end
      password { oauth_password }
      password_confirmation { oauth_password }
      after(:create) do |user|
        create(:user_identity, user: user, provider: "google")
      end
    end
  end
end
