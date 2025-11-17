require "rails_helper"

RSpec.describe Trigger, type: :model do
  describe "バリデーション" do
    it "有効なトリガーは保存できる" do
      trigger = build(:trigger)
      expect(trigger).to be_valid
    end

    it "keyがない場合は無効になる" do
      trigger = build(:trigger, key: nil)
      expect(trigger).not_to be_valid
    end

    it "keyが重複する場合は無効になる" do
      existing = create(:trigger, key: "duplicated")
      trigger = build(:trigger, key: existing.key)
      expect(trigger).not_to be_valid
    end

    it "keyが不正な形式の場合は無効になる" do
      trigger = build(:trigger, key: "INVALID-KEY")
      expect(trigger).not_to be_valid
    end

    it "categoryがenv/body以外の場合は無効になる" do
      trigger = build(:trigger, category: "invalid")
      expect(trigger).not_to be_valid
    end
  end

  describe "スコープ" do
    it "activeスコープで有効なトリガーのみ返す" do
      active_trigger = create(:trigger, :body)
      inactive_trigger = create(:trigger, :inactive)

      expect(Trigger.active).to include(active_trigger)
      expect(Trigger.active).not_to include(inactive_trigger)
    end
  end
end





