FactoryBot.define do
  factory :weather_observation do
    association :daily_log
    temperature_c { rand(-10.0..35.0).round(1) }
    humidity_pct { rand(30..90) }
    pressure_hpa { rand(900..1100) }
    observed_at { Time.current }
    snapshot { { "temperature" => temperature_c, "humidity" => humidity_pct, "pressure" => pressure_hpa } }

    trait :cold do
      temperature_c { rand(-10.0..5.0).round(1) }
    end

    trait :hot do
      temperature_c { rand(25.0..35.0).round(1) }
    end

    trait :low_pressure do
      pressure_hpa { rand(900..1000) }
    end

    trait :high_pressure do
      pressure_hpa { rand(1000..1100) }
    end
  end
end
