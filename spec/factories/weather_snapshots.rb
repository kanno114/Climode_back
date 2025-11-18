FactoryBot.define do
  factory :weather_snapshot do
    association :prefecture
    date { Date.current }
    metrics do
      {
        "pressure_drop_6h" => -6.4,
        "pressure_drop_24h" => -12.8,
        "humidity_avg" => 85.2,
        "temperature_drop_6h" => -3.5,
        "temperature_drop_12h" => -8.2
      }
    end
  end
end
