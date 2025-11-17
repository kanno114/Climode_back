FactoryBot.define do
  factory :user_trigger do
    association :user
    association :trigger
  end
end
