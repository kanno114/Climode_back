require 'rails_helper'

RSpec.describe UserIdentity, type: :model do
  describe 'バリデーション' do
    it '有効な属性を持つ場合は有効である' do
      user_identity = build(:user_identity)
      expect(user_identity).to be_valid
    end

    it 'ユーザーがない場合は無効である' do
      user_identity = build(:user_identity, user: nil)
      expect(user_identity).not_to be_valid
    end

    it 'プロバイダーがない場合は無効である' do
      user_identity = build(:user_identity, provider: nil)
      expect(user_identity).not_to be_valid
    end

    it 'UIDがない場合は無効である' do
      user_identity = build(:user_identity, uid: nil)
      expect(user_identity).not_to be_valid
    end

    it '同じプロバイダーとUIDの組み合わせで重複は無効である' do
      create(:user_identity, provider: 'google', uid: '12345')
      user_identity = build(:user_identity, provider: 'google', uid: '12345')
      expect(user_identity).not_to be_valid
    end

    it '異なるプロバイダーでは同じUIDを登録できる' do
      create(:user_identity, provider: 'google', uid: '12345')
      user_identity = build(:user_identity, provider: 'github', uid: '12345')
      expect(user_identity).to be_valid
    end

    it '同じプロバイダーでは異なるUIDを登録できる' do
      create(:user_identity, provider: 'google', uid: '12345')
      user_identity = build(:user_identity, provider: 'google', uid: '67890')
      expect(user_identity).to be_valid
    end
  end

  describe 'アソシエーション' do
    it 'ユーザーに属している' do
      user_identity = create(:user_identity)
      expect(user_identity.user).to be_present
    end
  end

  describe 'ファクトリー' do
    it '有効なユーザーアイデンティティを作成する' do
      user_identity = create(:user_identity)
      expect(user_identity).to be_persisted
      expect(user_identity.user).to be_present
      expect(user_identity.provider).to be_present
      expect(user_identity.uid).to be_present
    end

    it 'Googleのユーザーアイデンティティを作成する' do
      user_identity = create(:user_identity, :google)
      expect(user_identity.provider).to eq('google')
    end

    it 'GitHubのユーザーアイデンティティを作成する' do
      user_identity = create(:user_identity, :github)
      expect(user_identity.provider).to eq('github')
    end

    it 'Facebookのユーザーアイデンティティを作成する' do
      user_identity = create(:user_identity, :facebook)
      expect(user_identity.provider).to eq('facebook')
    end
  end

  describe 'スコープ' do
    let(:user) { create(:user) }
    let!(:google_identity) { create(:user_identity, :google, user: user) }
    let!(:github_identity) { create(:user_identity, :github, user: user) }
    let!(:facebook_identity) { create(:user_identity, :facebook, user: user) }

    it '指定したプロバイダーのアイデンティティを取得できる' do
      google_identities = UserIdentity.where(provider: 'google')
      expect(google_identities).to include(google_identity)
    end

    it '指定したユーザーのアイデンティティを取得できる' do
      user_identities = UserIdentity.where(user: user)
      expect(user_identities).to include(google_identity, github_identity, facebook_identity)
    end

    it '指定したUIDのアイデンティティを取得できる' do
      found_identity = UserIdentity.find_by(uid: google_identity.uid)
      expect(found_identity).to eq(google_identity)
    end
  end

  describe 'プロバイダー別の検索' do
    let(:user) { create(:user) }
    let!(:google_identity) { create(:user_identity, :google, user: user) }

    it 'Googleプロバイダーのアイデンティティを検索できる' do
      found_identity = UserIdentity.find_by(provider: 'google', uid: google_identity.uid)
      expect(found_identity).to eq(google_identity)
    end

    it '存在しないプロバイダーとUIDの組み合わせは見つからない' do
      found_identity = UserIdentity.find_by(provider: 'google', uid: 'nonexistent')
      expect(found_identity).to be_nil
    end
  end
end
