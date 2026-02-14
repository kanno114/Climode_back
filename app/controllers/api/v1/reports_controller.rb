class Api::V1::ReportsController < ApplicationController
  include Authenticatable

  # GET /api/v1/reports/weekly?start=YYYY-MM-DD
  def weekly
    week_start = if params[:start].present?
      begin
        Date.parse(params[:start])
      rescue ArgumentError
        render json: { error: "invalid_date", message: "無効な日付形式です。YYYY-MM-DD形式で指定してください。" },
               status: :bad_request
        return
      end
    else
      nil # WeeklyReportServiceで自動計算
    end

    service = Reports::WeeklyReportService.new(current_user, week_start)
    result = service.call

    render json: result
  end
end
