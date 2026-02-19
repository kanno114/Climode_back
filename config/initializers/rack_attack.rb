class Rack::Attack
  # テスト環境ではレート制限を無効化
  Rack::Attack.enabled = !Rails.env.test?

  # メモリストアを使用（Redis不要）
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  # ログインエンドポイントへのレート制限（ブルートフォース対策）
  # 同一IPから1分間に5回まで
  throttle("logins/ip", limit: 5, period: 60.seconds) do |req|
    if req.path == "/api/v1/sessions" && req.post?
      req.ip
    end
  end

  # パスワードリセットエンドポイントへのレート制限
  # 同一IPから10分間に3回まで
  throttle("password_resets/ip", limit: 3, period: 10.minutes) do |req|
    if req.path == "/api/v1/password_resets" && req.post?
      req.ip
    end
  end

  # 全APIエンドポイントへの基本レート制限
  # 同一IPから1分間に100リクエストまで
  throttle("api/ip", limit: 100, period: 60.seconds) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  # レート制限超過時のレスポンス
  self.throttled_responder = lambda do |_request|
    [
      429,
      { "Content-Type" => "application/json" },
      [ { error: "リクエスト制限を超えました。しばらく待ってから再度お試しください。" }.to_json ]
    ]
  end
end
