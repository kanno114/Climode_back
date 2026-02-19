require "rails_helper"

RSpec.describe User, "パスワードリセット", type: :model do
  let(:user) { create(:user) }

  describe "#generate_reset_password_token!" do
    it "平文トークンを返す" do
      token = user.generate_reset_password_token!
      expect(token).to be_present
      expect(token.length).to be > 20
    end

    it "ハッシュ化したトークンをDBに保存する" do
      token = user.generate_reset_password_token!
      user.reload
      expect(user.reset_password_token_digest).to be_present
      expect(user.reset_password_token_digest).not_to eq(token)
      expect(user.reset_password_token_digest).to eq(Digest::SHA256.hexdigest(token))
    end

    it "送信日時を記録する" do
      user.generate_reset_password_token!
      user.reload
      expect(user.reset_password_sent_at).to be_within(2.seconds).of(Time.current)
    end
  end

  describe "#reset_password_token_valid?" do
    it "トークンが有効期限内の場合はtrueを返す" do
      user.update!(reset_password_sent_at: 30.minutes.ago)
      expect(user.reset_password_token_valid?).to be true
    end

    it "トークンが有効期限切れの場合はfalseを返す" do
      user.update!(reset_password_sent_at: 2.hours.ago)
      expect(user.reset_password_token_valid?).to be false
    end

    it "送信日時がnilの場合はfalseを返す" do
      user.update!(reset_password_sent_at: nil)
      expect(user.reset_password_token_valid?).to be false
    end
  end

  describe "#reset_password!" do
    before do
      user.generate_reset_password_token!
    end

    it "パスワードを更新する" do
      user.reset_password!("newpassword123")
      user.reload
      expect(user.authenticate("newpassword123")).to be_truthy
    end

    it "トークン情報をクリアする" do
      user.reset_password!("newpassword123")
      user.reload
      expect(user.reset_password_token_digest).to be_nil
      expect(user.reset_password_sent_at).to be_nil
    end
  end

  describe ".find_by_reset_token" do
    it "正しいトークンでユーザーを見つける" do
      token = user.generate_reset_password_token!
      found_user = User.find_by_reset_token(token)
      expect(found_user).to eq(user)
    end

    it "不正なトークンではnilを返す" do
      user.generate_reset_password_token!
      expect(User.find_by_reset_token("invalid_token")).to be_nil
    end

    it "空のトークンではnilを返す" do
      expect(User.find_by_reset_token("")).to be_nil
      expect(User.find_by_reset_token(nil)).to be_nil
    end
  end
end
