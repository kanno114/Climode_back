class Api::V1::UsersController < ApplicationController
  include Authenticatable

  def show
    render json: {
      user: {
        id: current_user.id,
        email: current_user.email,
        name: current_user.name,
        prefecture_id: current_user.prefecture_id
      }
    }, status: :ok
  end

  def update
    if current_user.update(user_params)
      render json: {
        user: {
          id: current_user.id,
          email: current_user.email,
          name: current_user.name,
          prefecture_id: current_user.prefecture_id
        }
      }, status: :ok
    else
      render json: {
        errors: current_user.errors.full_messages,
        field_errors: current_user.errors.messages
      }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      errors: [e.message],
      field_errors: e.record.errors.messages
    }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "User update error: #{e.message}"
    render json: {
      errors: ['ユーザー情報の更新中にエラーが発生しました']
    }, status: :internal_server_error
  end

  private

  def user_params
    params.require(:user).permit(:name, :prefecture_id)
  end
end
