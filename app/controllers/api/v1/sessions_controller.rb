class Api::V1::SessionsController < ApplicationController

  def create
    if params[:user][:provider] && params[:user][:uid]
      authenticate_oauth_user
    else
      authenticate_email_user
    end
  end

  def refresh
    refresh_token = params[:refresh_token]
    
    if refresh_token.blank?
      render json: {
        error: 'リフレッシュトークンが提供されていません'
      }, status: :bad_request
      return
    end

    # まずトークンの形式をチェック（期限切れでもOK）
    payload = Auth::JwtService.decode_token_ignore_expiry(refresh_token)
    if payload.nil?
      render json: {
        error: '無効なリフレッシュトークンです'
      }, status: :unauthorized
      return
    end

    # 期限切れチェック
    unless Auth::JwtService.token_valid?(refresh_token)
      render json: {
        error: 'リフレッシュトークンの有効期限が切れています'
      }, status: :unauthorized
      return
    end

    # リフレッシュトークンかどうかチェック
    unless Auth::JwtService.refresh_token?(refresh_token)
      render json: {
        error: '無効なリフレッシュトークンです'
      }, status: :unauthorized
      return
    end

    user = Auth::JwtService.user_from_token(refresh_token)
    
    if user.nil?
      render json: {
        error: 'ユーザーが見つかりません'
      }, status: :unauthorized
      return
    end

    # 新しいアクセストークンを生成
    new_access_token = Auth::JwtService.generate_access_token(user)
    
    render json: {
      access_token: new_access_token,
      expires_in: Auth::JwtService::ACCESS_TOKEN_EXPIRY
    }, status: :ok
  rescue => e
    Rails.logger.error "Token refresh error: #{e.message}"
    render json: {
      error: 'トークンリフレッシュ中にエラーが発生しました'
    }, status: :internal_server_error
  end

  def destroy
    # リフレッシュトークンを受け取る（将来のブラックリスト管理用）
    refresh_token = params[:refresh_token]
    
    # 現在はステートレスなので、特にサーバー側での処理は不要
    # 将来的にRedis等でブラックリスト管理を実装する際はここで処理
    
    render json: {
      message: 'ログアウトしました'
    }, status: :ok
  end

  private

  def authenticate_oauth_user
    user_identity = UserIdentity.includes(:user).find_by(
      provider: params[:user][:provider],
      uid: params[:user][:uid]
    )

    if user_identity&.user
      user = user_identity.user
      access_token = Auth::JwtService.generate_access_token(user)
      refresh_token = Auth::JwtService.generate_refresh_token(user)
      
      render json: {
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          image: user.image || nil
        },
        access_token: access_token,
        refresh_token: refresh_token,
        expires_in: Auth::JwtService::ACCESS_TOKEN_EXPIRY
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
      access_token = Auth::JwtService.generate_access_token(user)
      refresh_token = Auth::JwtService.generate_refresh_token(user)
      
      render json: {
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          image: user.image || nil
        },
        access_token: access_token,
        refresh_token: refresh_token,
        expires_in: Auth::JwtService::ACCESS_TOKEN_EXPIRY
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
