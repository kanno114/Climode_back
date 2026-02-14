# frozen_string_literal: true

FactoryBot.define do
  factory :suggestion_rule do
    key { "heatstroke_Warning" }
    title { "暑い日" }
    message { "外出時は炎天下を避け、室内では室温の上昇に注意する。激しい運動は中止。" }
    tags { %w[temperature heatstroke] }
    severity { 75 }
    category { "env" }
    level { "Warning" }
    concerns { %w[heatstroke] }
    condition { "temperature_c >= 31 AND temperature_c < 35" }
    group { "temperature" }

    trait :pressure_drop do
      key { "pressure_drop_signal_warning" }
      title { "気圧変動に注意" }
      message { "気圧が急変動しています。体調に気をつけてください。" }
      tags { %w[weather pressure] }
      severity { 70 }
      category { "env" }
      concerns { %w[weather_pain] }
      condition { "max_pressure_drop_1h_awake <= -3.0" }
      group { "pressure" }
    end

    trait :low_mood do
      key { "low_mood" }
      title { "気分が低い" }
      message { "気分が落ち込んでいます。" }
      tags { %w[mood] }
      severity { 60 }
      category { "body" }
      concerns { %w[general] }
      condition { "mood < 3" }
      group { "mood" }
    end
  end
end
