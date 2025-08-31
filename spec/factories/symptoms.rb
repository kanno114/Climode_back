FactoryBot.define do
  factory :symptom do
    sequence(:code) { |n| "symptom_#{n}" }
    sequence(:name) { |n| "症状#{n}" }

    trait :headache do
      code { "headache" }
      name { "頭痛" }
    end

    trait :fatigue do
      code { "fatigue" }
      name { "疲労" }
    end

    trait :nausea do
      code { "nausea" }
      name { "吐き気" }
    end

    trait :dizziness do
      code { "dizziness" }
      name { "めまい" }
    end

    trait :joint_pain do
      code { "joint_pain" }
      name { "関節痛" }
    end
  end
end
