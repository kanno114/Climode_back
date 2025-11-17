require "rails_helper"

RSpec.describe UserTrigger, type: :model do
  describe "バリデーション" do
    it "有効なユーザートリガーは保存できる" do
      user_trigger = build(:user_trigger)
      expect(user_trigger).to be_valid
    end

    it "同じトリガーを重複登録できない" do
      existing = create(:user_trigger)
      duplicate = build(:user_trigger, user: existing.user, trigger: existing.trigger)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include("has already been taken")
    end

    it "非アクティブなトリガーは登録できない" do
      trigger = create(:trigger, :inactive)
      user_trigger = build(:user_trigger, trigger: trigger)

      expect(user_trigger).not_to be_valid
      expect(user_trigger.errors[:trigger]).to include("is not active")
    end
  end
end
