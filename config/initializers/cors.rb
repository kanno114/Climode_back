Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins [
      "http://front:3000",        # Docker内部
      "http://localhost:3000",    # ローカル開発
      "https://climode-front.vercel.app"  # 本番環境
    ]
    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: true
  end
end
