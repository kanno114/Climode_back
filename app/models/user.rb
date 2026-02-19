class User < ApplicationRecord
  has_secure_password

  belongs_to :prefecture, optional: true
  has_many :user_identities, dependent: :destroy
  has_many :daily_logs, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy
  has_many :user_concern_topics, dependent: :destroy
  has_many :concern_topics, through: :user_concern_topics

  validates :email, presence: true, uniqueness: true,
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, unless: :oauth_provider?
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  RESET_TOKEN_EXPIRY = 1.hour

  def oauth_provider?
    user_identities.exists?
  end

  # パスワードリセットトークンを生成し、ハッシュ化してDBに保存する
  # 平文トークンを返す（メールに含める用）
  def generate_reset_password_token!
    raw_token = SecureRandom.urlsafe_base64(32)
    update!(
      reset_password_token_digest: Digest::SHA256.hexdigest(raw_token),
      reset_password_sent_at: Time.current
    )
    raw_token
  end

  # パスワードリセットトークンが有効期限内かチェックする
  def reset_password_token_valid?
    reset_password_sent_at.present? &&
      reset_password_sent_at > RESET_TOKEN_EXPIRY.ago
  end

  # パスワードをリセットし、トークンを無効化する
  def reset_password!(new_password)
    update!(
      password: new_password,
      password_confirmation: new_password,
      reset_password_token_digest: nil,
      reset_password_sent_at: nil
    )
  end

  # 平文トークンからユーザーを検索する
  def self.find_by_reset_token(raw_token)
    return nil if raw_token.blank?

    digest = Digest::SHA256.hexdigest(raw_token)
    find_by(reset_password_token_digest: digest)
  end
end
