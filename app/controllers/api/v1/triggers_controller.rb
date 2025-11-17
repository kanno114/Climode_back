class Api::V1::TriggersController < ApplicationController
  include Authenticatable

  # GET /api/v1/triggers
  def index
    triggers = Trigger.active.order(:key)

    render json: triggers.as_json(
      only: [ :id, :key, :label, :category, :is_active, :version, :rule ]
    )
  end
end
