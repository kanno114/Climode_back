class Api::V1::UserTriggersController < ApplicationController
  include Authenticatable

  before_action :set_user_trigger, only: [ :destroy ]

  # GET /api/v1/user_triggers
  def index
    user_triggers = current_user.user_triggers.includes(:trigger).order(created_at: :asc)
    render json: user_triggers.as_json(
      only: [ :id, :created_at, :updated_at ],
      include: {
        trigger: {
          only: [ :id, :key, :label, :category, :is_active, :version, :rule ]
        }
      }
    )
  end

  # POST /api/v1/user_triggers
  def create
    trigger = resolve_trigger_from_params

    if trigger.nil?
      render json: { error: "Trigger not found" }, status: :not_found
      return
    end

    unless trigger.is_active?
      render json: { error: "Trigger is not active" }, status: :unprocessable_entity
      return
    end

    user_trigger = current_user.user_triggers.find_or_initialize_by(trigger: trigger)

    if user_trigger.persisted?
      render json: { error: "Trigger already registered" }, status: :conflict
      return
    end

    if user_trigger.save
      render json: user_trigger.as_json(
        only: [ :id, :created_at, :updated_at ],
        include: {
          trigger: {
            only: [ :id, :key, :label, :category, :is_active, :version, :rule ]
          }
        }
      ), status: :created
    else
      render json: { errors: user_trigger.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/user_triggers/:id
  def destroy
    return if @user_trigger.nil?

    @user_trigger.destroy
    head :no_content
  end

  private

  def resolve_trigger_from_params
    trigger_params = params.fetch(:user_trigger, {}).permit(:trigger_id, :trigger_key)
    trigger_id = (trigger_params[:trigger_id] || params[:trigger_id]).presence
    trigger_key = (trigger_params[:trigger_key] || params[:trigger_key]).presence

    if trigger_id
      Trigger.find_by(id: trigger_id)
    elsif trigger_key
      Trigger.find_by(key: trigger_key)
    else
      nil
    end
  end

  def set_user_trigger
    @user_trigger = current_user.user_triggers.find_by(id: params[:id])

    if @user_trigger.nil?
      render json: { error: "User trigger not found" }, status: :not_found
    end
  end
end
