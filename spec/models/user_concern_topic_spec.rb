require 'rails_helper'

RSpec.describe UserConcernTopic, type: :model do
  it "is valid with valid attributes" do
    topic = build(:user_concern_topic)
    expect(topic).to be_valid
  end

  it "requires concern_topic_id" do
    topic = build(:user_concern_topic, concern_topic: nil)
    expect(topic).not_to be_valid
    expect(topic.errors[:concern_topic]).to be_present
  end

  it "enforces uniqueness per user and concern_topic" do
    user = create(:user)
    concern_topic = ConcernTopic.find_or_create_by!(key: "heatstroke") do |c|
      c.label_ja = "熱中症"
      c.rule_concerns = ["heatstroke"]
      c.position = 1
      c.active = true
    end
    create(:user_concern_topic, user: user, concern_topic: concern_topic)
    duplicate = build(:user_concern_topic, user: user, concern_topic: concern_topic)
    expect(duplicate).not_to be_valid
  end
end
