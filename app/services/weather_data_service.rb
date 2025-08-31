class WeatherDataService
  def initialize(prefecture, date)
    @prefecture = prefecture
    @date = date
  end

  def fetch_weather_data
    # 現在はダミーデータを返す
    # 後でOpen-Meteo APIと連携する予定
    {
      temperature_c: rand(15.0..25.0).round(1),
      humidity_pct: rand(40.0..80.0).round(1),
      pressure_hpa: rand(1000.0..1020.0).round(1),
      observed_at: @date.to_datetime.change(hour: 9, minute: 0, second: 0),
      snapshot: {
        source: "dummy_data",
        prefecture_code: @prefecture.code,
        date: @date.to_s
      }
    }
  end
end
