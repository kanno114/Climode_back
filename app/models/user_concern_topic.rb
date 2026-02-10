class UserConcernTopic < ApplicationRecord
  belongs_to :user
  belongs_to :concern_topic, foreign_key: :concern_topic_key, primary_key: :key, optional: true

  validates :concern_topic_key, presence: true, uniqueness: { scope: :user_id }
end
