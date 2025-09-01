require 'httparty'

class WeatherDataService
  include HTTParty
  
  # Open-Meteo API設定
  base_uri 'https://api.open-meteo.com/v1'
  default_timeout 10
  
  def initialize(prefecture, date)
    @prefecture = prefecture
    @date = date
  end

  def fetch_weather_data
    return dummy_weather_data if Rails.env.test?
    
    begin
      response = fetch_from_api
      return dummy_weather_data unless response.success?
      
      parse_weather_response(response)
    rescue => e
      Rails.logger.error "Weather API error: #{e.message}"
      dummy_weather_data
    end
  end

  private

  def fetch_from_api
    options = {
      query: {
        latitude: @prefecture.centroid_lat,
        longitude: @prefecture.centroid_lon,
        hourly: 'temperature_2m,relative_humidity_2m,pressure_msl',
        timezone: 'Asia/Tokyo',
        start_date: @date.to_s,
        end_date: @date.to_s
      },
      headers: {
        'User-Agent' => 'Climode/1.0'
      }
    }
    
    self.class.get('/forecast', options)
  end

  def parse_weather_response(response)
    data = JSON.parse(response.body)
    
    # 9時のデータを取得（朝の体調記録に適した時間）
    hourly_data = data['hourly']
    return dummy_weather_data unless hourly_data
    
    # 9時のインデックスを取得、10時、8時のデータがない場合は最初のデータを使用
    time_index = hourly_data['time'].index { |time| time.include?('T09:00') }
    time_index ||= hourly_data['time'].index { |time| time.include?('T10:00') }
    time_index ||= hourly_data['time'].index { |time| time.include?('T08:00') }
    time_index ||= 0 # 9時のデータがない場合は最初のデータを使用
    
    # 実際の時刻を取得
    actual_time = hourly_data['time'][time_index]
    observed_datetime = actual_time ? DateTime.parse(actual_time) : @date.to_datetime.change(hour: 9, minute: 0, second: 0)
    
    {
      temperature_c: hourly_data['temperature_2m'][time_index],
      humidity_pct: hourly_data['relative_humidity_2m'][time_index],
      pressure_hpa: hourly_data['pressure_msl'][time_index],
      observed_at: observed_datetime,
      snapshot: {
        source: 'open_meteo_api',
        prefecture_code: @prefecture.code,
        date: @date.to_s,
        raw_response: data
      }
    }
  end

  def dummy_weather_data
    {
      temperature_c: rand(15.0..25.0).round(1),
      humidity_pct: rand(40.0..80.0).round(1),
      pressure_hpa: rand(1000.0..1020.0).round(1),
      observed_at: @date.to_datetime.change(hour: 9, minute: 0, second: 0),
      snapshot: {
        source: 'dummy_data',
        prefecture_code: @prefecture.code,
        date: @date.to_s
      }
    }
  end
end
