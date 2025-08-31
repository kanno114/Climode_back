FactoryBot.define do
  factory :daily_log_symptom do
    association :daily_log
    association :symptom
  end
end
