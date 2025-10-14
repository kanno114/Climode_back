class Api::V1::SymptomsController < ApplicationController
  # GET /api/v1/symptoms
  def index
    @symptoms = Symptom.all.order(:name)
    render json: @symptoms
  end

  # GET /api/v1/symptoms/:id
  def show
    @symptom = Symptom.find(params[:id])
    render json: @symptom
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Symptom not found" }, status: :not_found
  end
end
