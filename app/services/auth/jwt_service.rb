class Auth::JwtService
  # JWT秘密鍵（環境変数から取得、デフォルトは開発用）
  JWT_SECRET = ENV['JWT_SECRET'] || 'development_secret_key_change_in_production'
  
  # アクセストークンの有効期限（15分）
  ACCESS_TOKEN_EXPIRY = 15.minutes
  
  # リフレッシュトークンの有効期限（7日）
  REFRESH_TOKEN_EXPIRY = 7.days
  
  # アルゴリズム
  ALGORITHM = 'HS256'

  class << self
    # アクセストークンを生成
    def generate_access_token(user)
      payload = {
        user_id: user.id,
        email: user.email,
        exp: (Time.current + ACCESS_TOKEN_EXPIRY).to_i,
        iat: Time.current.to_i,
        type: 'access'
      }
      
      JWT.encode(payload, JWT_SECRET, ALGORITHM)
    end

    # リフレッシュトークンを生成
    def generate_refresh_token(user)
      payload = {
        user_id: user.id,
        email: user.email,
        exp: (Time.current + REFRESH_TOKEN_EXPIRY).to_i,
        iat: Time.current.to_i,
        type: 'refresh'
      }
      
      JWT.encode(payload, JWT_SECRET, ALGORITHM)
    end

    # トークンを検証してペイロードを返す
    def decode_token(token)
      JWT.decode(token, JWT_SECRET, true, { algorithm: ALGORITHM })
    rescue JWT::DecodeError => e
      Rails.logger.error "JWT decode error: #{e.message}"
      nil
    rescue JWT::ExpiredSignature => e
      Rails.logger.error "JWT expired: #{e.message}"
      # 注意：期限切れの場合もペイロードを返す（検証用）
      begin
        JWT.decode(token, JWT_SECRET, false, { algorithm: ALGORITHM })
      rescue
        nil
      end
    end

    # 署名検証はしない（false）、期限チェックもしないで中身だけ見る関数。検証用。
    def decode_token_ignore_expiry(token)
      JWT.decode(token, JWT_SECRET, false, { algorithm: ALGORITHM })
    rescue JWT::DecodeError => e
      Rails.logger.error "JWT decode error: #{e.message}"
      nil
    end

    # トークンからユーザーを取得
    def user_from_token(token)
      payload = decode_token(token)
      return nil unless payload
      
      payload_data = payload.first
      User.find_by(id: payload_data['user_id'])
    end

    # アクセストークンかどうかを確認
    def access_token?(token)
      payload = decode_token(token)
      return false unless payload
      
      payload.first['type'] == 'access'
    end

    # リフレッシュトークンかどうかを確認
    def refresh_token?(token)
      payload = decode_token(token)
      return false unless payload
      
      payload.first['type'] == 'refresh'
    end

    # トークンの有効期限を取得
    def token_expiry(token)
      payload = decode_token(token)
      return nil unless payload
      
      Time.at(payload.first['exp'])
    end

    # トークンが有効期限内かどうかを確認
    def token_valid?(token)
      payload = decode_token(token)
      return false unless payload
      
      # 期限切れの場合はfalse
      Time.current.to_i < payload.first['exp']
    rescue => e
      Rails.logger.error "Token validation error: #{e.message}"
      false
    end
  end
end
