require "httparty"

module Weather
  class WeatherDataService
    include HTTParty

    # Open-Meteo API設定
    base_uri "https://api.open-meteo.com/v1"
    default_timeout 10

    def initialize(prefecture, date, hour: 9)
      @prefecture = prefecture
      @date = date
      @hour = hour
    end

    def fetch_weather_data(hour: nil)
      target_hour = hour || @hour
      return dummy_weather_data(target_hour) if Rails.env.test?

      begin
        response = fetch_from_api
        return dummy_weather_data(target_hour) unless response.success?

        parse_weather_response(response, target_hour)
      rescue => e
        Rails.logger.error "Weather API error: #{e.message}"
        dummy_weather_data(target_hour)
      end
    end

    # 指定日の 24時間分などの時系列データを取得する
    # 戻り値: [{ time: DateTime, temperature_c: Float, pressure_hpa: Float, humidity_pct: Float, weather_code: Integer }, ...]
    def fetch_forecast_series(hours: 24)
      return dummy_forecast_series(hours: hours) if Rails.env.test?

      begin
        response = fetch_from_api
        return dummy_forecast_series(hours: hours) unless response.success?

        parse_forecast_series_response(response, hours: hours)
      rescue => e
        Rails.logger.error "Weather API (series) error: #{e.message}"
        dummy_forecast_series(hours: hours)
      end
    end

    private

    def fetch_from_api
      options = {
        query: {
          latitude: @prefecture.centroid_lat,
          longitude: @prefecture.centroid_lon,
          # 時系列予報向けに weather_code も取得
          hourly: "temperature_2m,relative_humidity_2m,pressure_msl,weather_code",
          timezone: "Asia/Tokyo",
          start_date: @date.to_s,
          end_date: @date.to_s
        },
        headers: {
          "User-Agent" => "Climode/1.0"
        }
      }

      self.class.get("/forecast", options)
    end

    # 24時間などの時系列に展開する
    def parse_forecast_series_response(response, hours: 24)
      data = JSON.parse(response.body)
      hourly_data = data["hourly"]
      return dummy_forecast_series(hours: hours) unless hourly_data

      times = hourly_data["time"] || []
      temps = hourly_data["temperature_2m"] || []
      humidities = hourly_data["relative_humidity_2m"] || []
      pressures = hourly_data["pressure_msl"] || []
      weather_codes = hourly_data["weather_code"] || []

      length = [
        times.length,
        temps.length,
        humidities.length,
        pressures.length,
        weather_codes.length
      ].min

      length = [length, hours].min

      series = []
      length.times do |i|
        time_str = times[i]
        time =
          begin
            DateTime.parse(time_str)
          rescue
            @date.to_datetime.change(hour: i, minute: 0, second: 0)
          end

        series << {
          time: time,
          temperature_c: temps[i],
          humidity_pct: humidities[i],
          pressure_hpa: pressures[i],
          weather_code: weather_codes[i]
        }
      end

      series
    end

    def parse_weather_response(response, hour = 9)
      data = JSON.parse(response.body)

      # 指定時刻のデータを取得（デフォルトは9時、朝の体調記録に適した時間）
      hourly_data = data["hourly"]
      return dummy_weather_data(hour) unless hourly_data

      # 指定時刻のインデックスを取得
      time_index = find_time_index(hourly_data["time"], hour)

      # 実際の時刻を取得
      actual_time = hourly_data["time"][time_index]
      observed_datetime = actual_time ? DateTime.parse(actual_time) : @date.to_datetime.change(hour: hour, minute: 0, second: 0)

      {
        temperature_c: hourly_data["temperature_2m"][time_index],
        humidity_pct: hourly_data["relative_humidity_2m"][time_index],
        pressure_hpa: hourly_data["pressure_msl"][time_index],
        observed_at: observed_datetime,
        snapshot: {
          source: "open_meteo_api",
          prefecture_code: @prefecture.code,
          date: @date.to_s,
          raw_response: data
        }
      }
    end

    def find_time_index(time_array, target_hour)
      # 指定時刻のデータを探す
      hour_str = format("%02d:00", target_hour)
      time_index = time_array.index { |time| time.include?("T#{hour_str}") }

      # 見つからない場合、前後の時刻を探す
      if time_index.nil?
        # 1時間前後を探す
        (1..3).each do |offset|
          prev_hour = (target_hour - offset) % 24
          next_hour = (target_hour + offset) % 24

          prev_str = format("%02d:00", prev_hour)
          next_str = format("%02d:00", next_hour)

          time_index ||= time_array.index { |time| time.include?("T#{prev_str}") }
          time_index ||= time_array.index { |time| time.include?("T#{next_str}") }
          break if time_index
        end
      end

      # それでも見つからない場合は最初のデータを使用
      time_index || 0
    end

    def dummy_weather_data(hour = 9)
      {
        temperature_c: rand(15.0..25.0).round(1),
        humidity_pct: rand(40.0..80.0).round(1),
        pressure_hpa: rand(1000.0..1020.0).round(1),
        observed_at: @date.to_datetime.change(hour: hour, minute: 0, second: 0),
        snapshot: {
          source: "dummy_data",
          prefecture_code: @prefecture.code,
          date: @date.to_s
        }
      }
    end

    # テストや障害時用のダミー時系列データ
    def dummy_forecast_series(hours: 24)
      Array.new(hours) do |i|
        hour = i % 24
        {
          time: @date.to_datetime.change(hour: hour, minute: 0, second: 0),
          temperature_c: rand(15.0..25.0).round(1),
          humidity_pct: rand(40.0..80.0).round(1),
          pressure_hpa: rand(1000.0..1020.0).round(1),
          weather_code: [0, 1, 2, 3, 45, 51, 61, 71, 95].sample # Open-Meteo に近いコードをざっくり
        }
      end
    end
  end
end
