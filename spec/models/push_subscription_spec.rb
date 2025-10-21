require "rails_helper"

RSpec.describe PushSubscription, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
  end

  describe "validations" do
    subject { build(:push_subscription) }

    it { should validate_presence_of(:endpoint) }
    it { should validate_presence_of(:p256dh_key) }
    it { should validate_presence_of(:auth_key) }
    it { should validate_uniqueness_of(:endpoint) }
  end

  describe "uniqueness validation" do
    let(:user) { create(:user) }
    let(:endpoint) { "https://example.com/push/endpoint" }

    before do
      create(:push_subscription, user: user, endpoint: endpoint)
    end

    it "does not allow duplicate endpoint" do
      duplicate_subscription = build(:push_subscription, user: user, endpoint: endpoint)
      expect(duplicate_subscription).not_to be_valid
      expect(duplicate_subscription.errors[:endpoint]).to include("has already been taken")
    end

    it "does not allow same user_id and endpoint combination" do
      duplicate_subscription = build(:push_subscription, user: user, endpoint: endpoint)
      expect(duplicate_subscription).not_to be_valid
    end
  end

  describe "cascade delete" do
    let(:user) { create(:user) }
    let!(:subscription) { create(:push_subscription, user: user) }

    it "deletes subscription when user is deleted" do
      expect { user.destroy }.to change(PushSubscription, :count).by(-1)
    end
  end
end


