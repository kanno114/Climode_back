require 'rails_helper'

RSpec.describe ConcernTopic, type: :model do
  it 'is valid with valid attributes' do
    topic = build(:concern_topic)
    expect(topic).to be_valid
  end

  it 'requires key and label_ja' do
    topic = build(:concern_topic, key: nil, label_ja: nil)
    expect(topic).not_to be_valid
    expect(topic.errors[:key]).to be_present
    expect(topic.errors[:label_ja]).to be_present
  end

  it 'enforces unique key' do
    create(:concern_topic, key: 'unique_key')
    duplicate = build(:concern_topic, key: 'unique_key')
    expect(duplicate).not_to be_valid
  end

  describe '.active' do
    it 'returns only active topics ordered by position and id' do
      UserConcernTopic.delete_all
      described_class.delete_all

      inactive = create(:concern_topic, active: false, position: 1)
      topic1 = create(:concern_topic, active: true, position: 2)
      topic2 = create(:concern_topic, active: true, position: 1)

      result = described_class.active
      expect(result).to eq([ topic2, topic1 ])
      expect(result).not_to include(inactive)
    end
  end
end
