require 'rails_helper'

RSpec.describe Prefecture, type: :model do
  describe 'バリデーション' do
    it '有効な属性を持つ場合は有効である' do
      prefecture = build(:prefecture)
      expect(prefecture).to be_valid
    end

    it 'コードがない場合は無効である' do
      prefecture = build(:prefecture, code: nil)
      expect(prefecture).not_to be_valid
    end

    it '日本語名がない場合は無効である' do
      prefecture = build(:prefecture, name_ja: nil)
      expect(prefecture).not_to be_valid
    end

    it '重複したコードの場合は無効である' do
      create(:prefecture, code: '01')
      prefecture = build(:prefecture, code: '01')
      expect(prefecture).not_to be_valid
    end
  end

  describe 'アソシエーション' do
    it '複数のユーザーを持っている' do
      prefecture = create(:prefecture)
      users = create_list(:user, 3, prefecture: prefecture)
      expect(prefecture.users).to match_array(users)
    end

    it '複数の日次ログを持っている' do
      prefecture = create(:prefecture)
      daily_logs = create_list(:daily_log, 3, prefecture: prefecture)
      expect(prefecture.daily_logs).to match_array(daily_logs)
    end
  end

  describe 'ファクトリー' do
    it '有効な都道府県を作成する' do
      prefecture = create(:prefecture)
      expect(prefecture).to be_persisted
      expect(prefecture.code).to be_present
      expect(prefecture.name_ja).to be_present
    end

    it '東京都を作成する' do
      prefecture = create(:prefecture, :tokyo)
      expect(prefecture.code).to eq('13')
      expect(prefecture.name_ja).to eq('東京都')
    end

    it '大阪府を作成する' do
      prefecture = create(:prefecture, :osaka)
      expect(prefecture.code).to eq('27')
      expect(prefecture.name_ja).to eq('大阪府')
    end
  end
end
