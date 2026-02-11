class UserConcernTopic < ApplicationRecord
  belongs_to :user
  belongs_to :concern_topic

  validates :concern_topic_id, uniqueness: { scope: :user_id }
end
