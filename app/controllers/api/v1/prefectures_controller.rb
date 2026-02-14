class Api::V1::PrefecturesController < ApplicationController
  # GET /api/v1/prefectures
  def index
    @prefectures = Prefecture.all.order(:code)
    render json: @prefectures
  end

  # GET /api/v1/prefectures/:id
  def show
    @prefecture = Prefecture.find(params[:id])
    render json: @prefecture
  rescue ActiveRecord::RecordNotFound
    render json: { error: "not_found", message: "都道府県が見つかりません" }, status: :not_found
  end
end
