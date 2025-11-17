class Trigger < ApplicationRecord
  CATEGORIES = %w[env body].freeze

  has_many :user_triggers, dependent: :restrict_with_exception
  has_many :users, through: :user_triggers

  scope :active, -> { where(is_active: true) }

  validates :key, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/ }
  validates :label, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :version, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
