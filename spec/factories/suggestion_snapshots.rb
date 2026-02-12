# frozen_string_literal: true

FactoryBot.define do
  factory :suggestion_snapshot do
    date { Date.current }
    association :prefecture
    rule_key { "heatstroke_Warning" }
    title { "暑い日" }
    message { "外出時は炎天下を避け、室内では室温の上昇に注意する。激しい運動は中止。" }
    tags { [ "temperature", "heatstroke" ] }
    severity { 75 }
    category { "env" }
    metadata do
      {
        "temperature_c" => 32.0,
        "min_temperature_c" => 22.0,
        "humidity_pct" => 50.0,
        "pressure_hpa" => 1013.0,
        "max_pressure_drop_1h_awake" => 0.0,
        "low_pressure_duration_1003h" => 0.0,
        "low_pressure_duration_1007h" => 0.0,
        "pressure_range_3h_awake" => 0.0,
        "pressure_jitter_3h_awake" => 0.0
      }
    end
  end
end
