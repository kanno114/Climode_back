class Api::V1::SessionsController < ApplicationController

  def create
    if params[:user][:provider] && params[:user][:uid]
      authenticate_oauth_user
    else
      authenticate_email_user
    end
  end

  private

  def authenticate_oauth_user
    user_identity = UserIdentity.includes(:user).find_by(
      provider: params[:user][:provider],
      uid: params[:user][:uid]
    )

    if user_identity&.user
      render json: {
        id: user_identity.user.id,
        email: user_identity.user.email,
        name: user_identity.user.name,
        image: user_identity.user.image || nil,
        provider: user_identity.provider,
        uid: user_identity.uid
      }, status: :ok
    else
      render json: {
        error: "認証に失敗しました",
        details: "OAuthユーザーが見つかりません"
      }, status: :unauthorized
    end
  rescue => e
    Rails.logger.error "OAuth authentication error: #{e.message}"
    render json: {
      error: "認証処理中にエラーが発生しました"
    }, status: :internal_server_error
  end

  def authenticate_email_user
    user = User.find_by(email: params[:user][:email])

    if user.nil?
      render json: {
        error: "認証に失敗しました",
        details: "メールアドレスまたはパスワードが正しくありません"
      }, status: :unauthorized
      return
    end

    if user&.authenticate(params[:user][:password])
      render json: {
        id: user.id,
        email: user.email,
        name: user.name,
        image: user.image || nil,
        provider: "email"
      }, status: :ok
    else
      render json: {
        error: "認証に失敗しました",
        details: "メールアドレスまたはパスワードが正しくありません"
      }, status: :unauthorized
    end
  rescue => e
    Rails.logger.error "Email authentication error: #{e.message}"
    render json: {
      error: "認証処理中にエラーが発生しました"
    }, status: :internal_server_error
  end
end
