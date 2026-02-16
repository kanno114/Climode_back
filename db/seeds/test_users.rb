# ============================================================================
# テストユーザー（開発・テスト環境のみ）
#
# 役割分担:
#   Alice — ヘビーユーザー（全機能確認用）: 東京、関心トピック全5件
#   Bob   — 一部機能利用（フィルタリング確認用）: 大阪、関心トピック2件
#   Carol — 新規ユーザー（オンボーディング確認用）: 都道府県なし、データなし
# ============================================================================

puts "Seeding test users..."

users = [
  { name: "Alice", email: "alice@example.com", password: "password123", password_confirmation: "password123" },
  { name: "Bob", email: "bob@example.com", password: "password123", password_confirmation: "password123" },
  { name: "Carol", email: "carol@example.com", password: "password123", password_confirmation: "password123" }
]

users.each do |attrs|
  user = User.find_by(email: attrs[:email])
  if user
    puts "  already exists: #{user.email}"
  else
    User.create!(
      name: attrs[:name],
      email: attrs[:email],
      password: attrs[:password],
      password_confirmation: attrs[:password_confirmation]
    )
    puts "  created: #{attrs[:email]}"
  end
end

# Alice: 都道府県を東京に設定
alice = User.find_by!(email: "alice@example.com")
tokyo = Prefecture.find_by!(code: "13")
alice.update!(prefecture: tokyo) if alice.prefecture.nil?

# Bob: 都道府県を大阪に設定（地域別天気提案の確認用）
bob = User.find_by!(email: "bob@example.com")
osaka = Prefecture.find_by!(code: "27")
bob.update!(prefecture: osaka) if bob.prefecture.nil?

# Alice に全関心トピックを登録
ConcernTopic.find_each do |topic|
  UserConcernTopic.find_or_create_by!(user: alice, concern_topic: topic)
end
puts "  Registered all concern topics for Alice (#{ConcernTopic.count} topics)"

# Bob に関心トピック2件（sleep_time, weather_pain）を登録
%w[sleep_time weather_pain].each do |key|
  topic = ConcernTopic.find_by!(key: key)
  UserConcernTopic.find_or_create_by!(user: bob, concern_topic: topic)
end
puts "  Registered 2 concern topics for Bob (sleep_time, weather_pain)"
