class Api::V1::UsersController < ApplicationController
  include Authenticatable

  def show
    render json: {
      user: {
        id: current_user.id,
        email: current_user.email,
        name: current_user.name,
        prefecture_id: current_user.prefecture_id,
        email_confirmed: current_user.email_confirmed?
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

  def destroy
    unless current_user.id == params[:id].to_i
      render json: {
        error: "forbidden",
        message: "この操作を実行する権限がありません"
      }, status: :forbidden
      return
    end

    if current_user.oauth_provider?
      unless params[:confirm] == true || params[:confirm] == "true"
        render json: {
          error: "confirmation_required",
          message: "アカウント削除の確認が必要です"
        }, status: :unprocessable_entity
        return
      end
    else
      unless current_user.authenticate(params[:password])
        render json: {
          error: "invalid_password",
          message: "パスワードが正しくありません"
        }, status: :unprocessable_entity
        return
      end
    end

    ActiveRecord::Base.transaction do
      current_user.destroy!
    end

    head :no_content
  rescue ActiveRecord::RecordNotDestroyed => e
    Rails.logger.error "Account deletion error: #{e.message}"
    render json: {
      error: "deletion_failed",
      message: "アカウントの削除に失敗しました"
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
