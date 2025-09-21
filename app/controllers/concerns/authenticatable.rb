module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  def authenticate_user!
    token = extract_token_from_header
    
    if token.blank?
      render_unauthorized('認証トークンが提供されていません')
      return
    end

    # まずトークンの形式をチェック（期限切れでもOK）
    payload = Auth::JwtService.decode_token_ignore_expiry(token)
    if payload.nil?
      render_unauthorized('無効な認証トークンです')
      return
    end

    # 期限切れチェック
    unless Auth::JwtService.token_valid?(token)
      render_unauthorized('認証トークンの有効期限が切れています')
      return
    end

    # アクセストークンかどうかチェック
    unless Auth::JwtService.access_token?(token)
      render_unauthorized('アクセストークンが必要です')
      return
    end

    @current_user = Auth::JwtService.user_from_token(token)
    
    if @current_user.nil?
      render_unauthorized('無効な認証トークンです')
      return
    end
  rescue => e
    Rails.logger.error "Authentication error: #{e.message}"
    render_unauthorized('認証処理中にエラーが発生しました')
  end

  def current_user
    @current_user
  end

  def extract_token_from_header
    auth_header = request.headers['Authorization']
    return nil unless auth_header&.start_with?('Bearer ')
    
    auth_header.split(' ').last
  end

  def render_unauthorized(message)
    render json: {
      error: '認証エラー',
      message: message
    }, status: :unauthorized
  end
end
