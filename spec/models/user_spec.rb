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
