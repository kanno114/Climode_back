require 'rails_helper'

RSpec.describe UserConcernTopic, type: :model do
  it "is valid with valid attributes" do
    topic = build(:user_concern_topic)
    expect(topic).to be_valid
  end

  it "requires concern_topic_key" do
    topic = build(:user_concern_topic, concern_topic_key: nil)
    expect(topic).not_to be_valid
    expect(topic.errors[:concern_topic_key]).to be_present
  end

  it "enforces uniqueness per user and key" do
    user = create(:user)
    create(:user_concern_topic, user: user, concern_topic_key: "heatstroke")
    duplicate = build(:user_concern_topic, user: user, concern_topic_key: "heatstroke")
    expect(duplicate).not_to be_valid
  end
end
