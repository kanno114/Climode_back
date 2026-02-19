require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  describe "#reset_password_email" do
    let(:user) { create(:user, email: "test@example.com") }
    let(:raw_token) { "test_reset_token_123" }
    let(:mail) { described_class.reset_password_email(user, raw_token) }

    it "正しい宛先に送信される" do
      expect(mail.to).to eq([ "test@example.com" ])
    end

    it "正しい件名が設定される" do
      expect(mail.subject).to eq("【Climode】パスワードの再設定")
    end

    it "リセットURLがHTML本文に含まれる" do
      expect(mail.html_part.body.to_s).to include("reset-password?token=test_reset_token_123")
    end

    it "リセットURLがテキスト本文に含まれる" do
      expect(mail.text_part.body.to_s).to include("reset-password?token=test_reset_token_123")
    end

    it "有効期限の案内が本文に含まれる" do
      expect(mail.html_part.body.to_s).to include("1時間後に無効")
    end
  end

  describe "#confirmation_email" do
    let(:user) { create(:user, email: "newuser@example.com") }
    let(:raw_token) { "test_confirmation_token_456" }
    let(:mail) { described_class.confirmation_email(user, raw_token) }

    it "正しい宛先に送信される" do
      expect(mail.to).to eq([ "newuser@example.com" ])
    end

    it "正しい件名が設定される" do
      expect(mail.subject).to eq("【Climode】メールアドレスの確認")
    end

    it "確認URLがHTML本文に含まれる" do
      expect(mail.html_part.body.to_s).to include("confirm-email?token=test_confirmation_token_456")
    end

    it "確認URLがテキスト本文に含まれる" do
      expect(mail.text_part.body.to_s).to include("confirm-email?token=test_confirmation_token_456")
    end

    it "有効期限の案内が本文に含まれる" do
      expect(mail.html_part.body.to_s).to include("24時間後に無効")
    end
  end
end
