class User < ApplicationRecord
  has_secure_password

  belongs_to :prefecture, optional: true
  has_many :user_identities, dependent: :destroy
  has_many :daily_logs, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true, unless: :oauth_provider?

  def oauth_provider?
    user_identities.exists?
  end
end
