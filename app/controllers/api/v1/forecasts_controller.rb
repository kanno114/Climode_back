class Api::V1::ForecastsController < ApplicationController
  include Authenticatable

  # GET /api/v1/forecast
  # クエリパラメータ:
  #   date: YYYY-MM-DD（省略時は今日）
  #   hours: 取得したい件数（省略時は24、最大48など）
  def index
    unless current_user&.prefecture
      render json: { error: "prefecture_not_set" }, status: :unprocessable_entity
      return
    end

    date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    hours = params[:hours].presence&.to_i
    hours = 24 if hours.nil? || hours <= 0
    hours = 48 if hours > 48

    snapshot = WeatherSnapshot.for_prefecture(current_user.prefecture).for_date(date).first
    if snapshot.present? && snapshot.metrics["hourly_forecast"].present? && snapshot.metrics["hourly_forecast"].is_a?(Array) && snapshot.metrics["hourly_forecast"].any?
      cached = snapshot.metrics["hourly_forecast"].first(hours)
      render json: cached
      return
    end

    service = Weather::WeatherDataService.new(current_user.prefecture, date)
    series = service.fetch_forecast_series(hours: hours)
    json = series.map { |point|
      {
        time: point[:time].iso8601,
        temperature_c: point[:temperature_c],
        humidity_pct: point[:humidity_pct],
        pressure_hpa: point[:pressure_hpa],
        weather_code: point[:weather_code]
      }
    }
    Weather::WeatherSnapshotService.save_hourly_forecast(current_user.prefecture, date, series)
    render json: json
  rescue ArgumentError => e
    # Date.parse などで不正な日付が渡された場合
    render json: { error: "invalid_date", message: e.message }, status: :bad_request
  end
end
