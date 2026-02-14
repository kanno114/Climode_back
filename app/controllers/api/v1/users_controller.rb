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
        error: "validation_error",
        message: "入力内容に誤りがあります",
        details: current_user.errors.messages
      }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      error: "validation_error",
      message: e.message,
      details: e.record.errors.messages
    }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "User update error: #{e.message}"
    render json: {
      error: "internal_error",
      message: "ユーザー情報の更新中にエラーが発生しました"
    }, status: :internal_server_error
  end

  def default_prefecture
    render json: {
      prefecture: current_user.prefecture
    }, status: :ok
  end

  private

  def user_params
    params.require(:user).permit(:name, :prefecture_id)
  end
end
