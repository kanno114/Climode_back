class ConcernTopic < ApplicationRecord
  has_many :user_concern_topics, dependent: :destroy
  has_many :users, through: :user_concern_topics

  validates :key, presence: true, uniqueness: true
  validates :label_ja, presence: true

  scope :active, -> { where(active: true).order(:position, :id) }
end
