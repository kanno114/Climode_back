class Auth::JwtService
  # JWT秘密鍵（本番環境ではENV必須、開発・テストはデフォルト値を使用）
  JWT_SECRET = ENV["JWT_SECRET"] || (Rails.env.production? ? raise("JWT_SECRET環境変数が設定されていません") : "development_secret_key_change_in_production")

  # アクセストークンの有効期限（30日）
  ACCESS_TOKEN_EXPIRY = 30.days

  # アルゴリズム
  ALGORITHM = "HS256"

  class << self
    # アクセストークンを生成
    def generate_access_token(user)
      payload = {
        user_id: user.id,
        email: user.email,
        exp: (Time.current + ACCESS_TOKEN_EXPIRY).to_i,
        iat: Time.current.to_i,
        type: "access"
      }

      JWT.encode(payload, JWT_SECRET, ALGORITHM)
    end

    # トークンを検証してペイロードを返す（期限切れでも署名検証は維持してペイロードを返す）
    def decode_token(token)
      JWT.decode(token, JWT_SECRET, true, { algorithm: ALGORITHM })
    rescue JWT::ExpiredSignature
      # 期限切れの場合も署名検証を維持しつつペイロードを返す
      JWT.decode(token, JWT_SECRET, true, { algorithm: ALGORITHM, verify_expiration: false })
    rescue JWT::DecodeError => e
      Rails.logger.error "JWT decode error: #{e.message}"
      nil
    end

    # トークンからユーザーを取得
    def user_from_token(token)
      payload = decode_token(token)
      return nil unless payload

      payload_data = payload.first
      User.find_by(id: payload_data["user_id"])
    end

    # アクセストークンかどうかを確認
    def access_token?(token)
      payload = decode_token(token)
      return false unless payload

      payload.first["type"] == "access"
    end

    # トークンの有効期限を取得
    def token_expiry(token)
      payload = decode_token(token)
      return nil unless payload

      Time.at(payload.first["exp"])
    end

    # トークンが有効期限内かどうかを確認
    def token_valid?(token)
      payload = decode_token(token)
      return false unless payload

      # 期限切れの場合はfalse
      Time.current.to_i < payload.first["exp"]
    rescue => e
      Rails.logger.error "Token validation error: #{e.message}"
      false
    end
  end
end
