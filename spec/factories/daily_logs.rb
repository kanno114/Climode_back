FactoryBot.define do
  factory :daily_log do
    association :user
    association :prefecture
    sequence(:date) { |n| Date.current + n.days }
    sleep_hours { rand(6.0..9.0).round(1) }
    mood { rand(1..5) }
    fatigue { rand(1..5) }
    self_score { rand(1..3) }
    note { Faker::Lorem.sentence }

    trait :yesterday do
      date { Date.yesterday }
    end

    trait :last_week do
      date { 1.week.ago.to_date }
    end
  end
end
