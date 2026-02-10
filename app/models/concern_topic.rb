class ConcernTopic < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :label_ja, presence: true

  scope :active, -> { where(active: true).order(:position, :id) }
end
