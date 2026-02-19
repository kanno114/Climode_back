require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'バリデーション' do
    it '有効な属性を持つ場合は有効である' do
      user = build(:user)
      expect(user).to be_valid
    end

    it 'メールアドレスがない場合は無効である' do
      user = build(:user, email: nil)
      expect(user).not_to be_valid
    end

    it '重複したメールアドレスの場合は無効である' do
      # 既存のデータをクリーンアップ
      User.where(email: 'test@example.com').destroy_all
      create(:user, email: 'test@example.com')
      user = build(:user, email: 'test@example.com')
      expect(user).not_to be_valid
    end
  end

  describe 'アソシエーション' do
    it '都道府県に属している' do
      user = create(:user)
      expect(user.prefecture).to be_present
    end

    it '複数の日次ログを持っている' do
      user = create(:user)
      daily_logs = create_list(:daily_log, 3, user: user)
      expect(user.daily_logs).to match_array(daily_logs)
    end

    it '複数のユーザーアイデンティティを持っている' do
      user = create(:user)
      identities = create_list(:user_identity, 2, user: user)
      expect(user.user_identities).to match_array(identities)
    end
  end

  describe 'メール確認' do
    let(:user) { create(:user) }

    describe '#generate_confirmation_token!' do
      it 'トークンを生成して保存する' do
        raw_token = user.generate_confirmation_token!
        expect(raw_token).to be_present
        expect(user.reload.confirmation_token_digest).to be_present
        expect(user.confirmation_sent_at).to be_present
      end

      it '生成されたトークンのダイジェストがDBに保存される' do
        raw_token = user.generate_confirmation_token!
        expected_digest = Digest::SHA256.hexdigest(raw_token)
        expect(user.reload.confirmation_token_digest).to eq(expected_digest)
      end
    end

    describe '#confirmation_token_valid?' do
      it '有効期限内であればtrueを返す' do
        user.update!(confirmation_sent_at: 1.hour.ago)
        expect(user.confirmation_token_valid?).to be true
      end

      it '有効期限切れ（24時間超過）であればfalseを返す' do
        user.update!(confirmation_sent_at: 25.hours.ago)
        expect(user.confirmation_token_valid?).to be false
      end

      it 'confirmation_sent_atがnilであればfalseを返す' do
        user.update!(confirmation_sent_at: nil)
        expect(user.confirmation_token_valid?).to be false
      end
    end

    describe '#confirm_email!' do
      it 'メール確認を完了する' do
        user.update!(email_confirmed: false, confirmation_token_digest: 'test', confirmation_sent_at: Time.current)
        user.confirm_email!
        user.reload
        expect(user.email_confirmed?).to be true
        expect(user.confirmation_token_digest).to be_nil
        expect(user.confirmation_sent_at).to be_nil
      end
    end

    describe '.find_by_confirmation_token' do
      it '正しいトークンでユーザーを見つける' do
        raw_token = user.generate_confirmation_token!
        found_user = User.find_by_confirmation_token(raw_token)
        expect(found_user).to eq(user)
      end

      it '不正なトークンではnilを返す' do
        expect(User.find_by_confirmation_token('invalid_token')).to be_nil
      end

      it '空のトークンではnilを返す' do
        expect(User.find_by_confirmation_token('')).to be_nil
        expect(User.find_by_confirmation_token(nil)).to be_nil
      end
    end

    describe '.confirmed' do
      it '確認済みユーザーのみを返す' do
        confirmed_user = create(:user, email_confirmed: true)
        unconfirmed_user = create(:user, email_confirmed: false)
        expect(User.confirmed).to include(confirmed_user)
        expect(User.confirmed).not_to include(unconfirmed_user)
      end
    end
  end

  describe 'ファクトリー' do
    it '有効なユーザーを作成する' do
      user = create(:user)
      expect(user).to be_persisted
      expect(user.email).to be_present
      expect(user.name).to be_present
    end

    it '画像付きのユーザーを作成する' do
      user = create(:user, :with_image)
      expect(user.image).to be_present
    end
  end
end
