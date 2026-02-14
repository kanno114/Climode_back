class Api::V1::SessionsController < ApplicationController
  def create
    if params[:user][:provider] && params[:user][:uid]
      authenticate_oauth_user
    else
      authenticate_email_user
    end
  end

  def validate_token
    token = extract_token_from_header

    if token.blank?
      render json: {
        valid: false,
        error: "unauthorized",
        message: "認証トークンが提供されていません"
      }, status: :unauthorized
      return
    end

    # トークンの形式をチェック（署名検証あり）
    payload = Auth::JwtService.decode_token(token)
    if payload.nil?
      render json: {
        valid: false,
        error: "unauthorized",
        message: "無効な認証トークンです"
      }, status: :unauthorized
      return
    end

    # 期限切れチェック
    unless Auth::JwtService.token_valid?(token)
      render json: {
        valid: false,
        error: "unauthorized",
        message: "認証トークンの有効期限が切れています"
      }, status: :unauthorized
      return
    end

    # アクセストークンかどうかチェック
    unless Auth::JwtService.access_token?(token)
      render json: {
        valid: false,
        error: "unauthorized",
        message: "アクセストークンが必要です"
      }, status: :unauthorized
      return
    end

    # ユーザーの存在確認
    user = Auth::JwtService.user_from_token(token)
    if user.nil?
      render json: {
        valid: false,
        error: "unauthorized",
        message: "無効な認証トークンです"
      }, status: :unauthorized
      return
    end

    # 有効なトークン
    render json: {
      valid: true,
      user_id: user.id,
      email: user.email
    }, status: :ok
  rescue => e
    Rails.logger.error "Token validation error: #{e.message}"
    render json: {
      valid: false,
      error: "internal_error",
      message: "認証処理中にエラーが発生しました"
    }, status: :internal_server_error
  end

  private

  def extract_token_from_header
    auth_header = request.headers["Authorization"]
    return nil unless auth_header&.start_with?("Bearer ")

    auth_header.split(" ").last
  end

  def authenticate_oauth_user
    user_identity = UserIdentity.includes(:user).find_by(
      provider: params[:user][:provider],
      uid: params[:user][:uid]
    )

    if user_identity&.user
      user = user_identity.user
      access_token = Auth::JwtService.generate_access_token(user)

      render json: {
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          image: user.image || nil
        },
        access_token: access_token,
        expires_in: Auth::JwtService::ACCESS_TOKEN_EXPIRY
      }, status: :ok
    else
      render json: {
        error: "unauthorized",
        message: "OAuthユーザーが見つかりません"
      }, status: :unauthorized
    end
  rescue => e
    Rails.logger.error "OAuth authentication error: #{e.message}"
    render json: {
      error: "internal_error",
      message: "認証処理中にエラーが発生しました"
    }, status: :internal_server_error
  end

  def authenticate_email_user
    user = User.find_by(email: params[:user][:email])

    if user.nil?
      render json: {
        error: "unauthorized",
        message: "メールアドレスまたはパスワードが正しくありません"
      }, status: :unauthorized
      return
    end

    if user&.authenticate(params[:user][:password])
      access_token = Auth::JwtService.generate_access_token(user)

      render json: {
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          image: user.image || nil
        },
        access_token: access_token,
        expires_in: Auth::JwtService::ACCESS_TOKEN_EXPIRY
      }, status: :ok
    else
      render json: {
        error: "unauthorized",
        message: "メールアドレスまたはパスワードが正しくありません"
      }, status: :unauthorized
    end
  rescue => e
    Rails.logger.error "Email authentication error: #{e.message}"
    render json: {
      error: "internal_error",
      message: "認証処理中にエラーが発生しました"
    }, status: :internal_server_error
  end
end
