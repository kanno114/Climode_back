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

  def oauth_provider?
    user_identities.exists?
  end
end
