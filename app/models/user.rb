class User < ApplicationRecord
  has_secure_password

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true, unless: :oauth_provider?

  def oauth_provider?
    provider.present?
  end
end


