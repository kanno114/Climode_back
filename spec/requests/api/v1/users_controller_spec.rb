require "rails_helper"

RSpec.describe "Api::V1::UsersController", type: :request do
  include AuthHelper

  let(:user) { create(:user, password: "password123", password_confirmation: "password123") }
  let(:token) { generate_jwt_token(user) }
  let(:headers) { { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" } }

  describe "DELETE /api/v1/users/:id" do
    context "パスワード認証ユーザー" do
      it "正しいパスワードでアカウントを削除できる" do
        delete "/api/v1/users/#{user.id}", params: { password: "password123" }.to_json, headers: headers

        expect(response).to have_http_status(:no_content)
        expect(User.find_by(id: user.id)).to be_nil
      end

      it "関連データがカスケード削除される" do
        daily_log = create(:daily_log, user: user)
        push_sub = create(:push_subscription, user: user)
        uct = create(:user_concern_topic, user: user)

        delete "/api/v1/users/#{user.id}", params: { password: "password123" }.to_json, headers: headers

        expect(response).to have_http_status(:no_content)
        expect(User.find_by(id: user.id)).to be_nil
        expect(DailyLog.find_by(id: daily_log.id)).to be_nil
        expect(PushSubscription.find_by(id: push_sub.id)).to be_nil
        expect(UserConcernTopic.find_by(id: uct.id)).to be_nil
      end

      it "パスワードが不正な場合は422を返す" do
        delete "/api/v1/users/#{user.id}", params: { password: "wrong_password" }.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("invalid_password")
        expect(User.find_by(id: user.id)).to be_present
      end

      it "パスワードが未入力の場合は422を返す" do
        delete "/api/v1/users/#{user.id}", params: {}.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("invalid_password")
      end
    end

    context "OAuthユーザー" do
      let(:oauth_user) { create(:user) }
      let!(:identity) { create(:user_identity, user: oauth_user) }
      let(:oauth_token) { generate_jwt_token(oauth_user) }
      let(:oauth_headers) { { "Authorization" => "Bearer #{oauth_token}", "Content-Type" => "application/json" } }

      it "confirm: trueでアカウントを削除できる" do
        delete "/api/v1/users/#{oauth_user.id}", params: { confirm: true }.to_json, headers: oauth_headers

        expect(response).to have_http_status(:no_content)
        expect(User.find_by(id: oauth_user.id)).to be_nil
      end

      it "confirm: trueが未指定の場合は422を返す" do
        delete "/api/v1/users/#{oauth_user.id}", params: {}.to_json, headers: oauth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("confirmation_required")
        expect(User.find_by(id: oauth_user.id)).to be_present
      end
    end

    context "他ユーザーのアカウント削除" do
      let(:other_user) { create(:user) }

      it "403を返す" do
        delete "/api/v1/users/#{other_user.id}", params: { password: "password123" }.to_json, headers: headers

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("forbidden")
        expect(User.find_by(id: other_user.id)).to be_present
      end
    end

    context "存在しないユーザーID" do
      it "403を返す（ユーザー列挙防止）" do
        delete "/api/v1/users/999999", params: { password: "password123" }.to_json, headers: headers

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("forbidden")
      end
    end

    context "未認証" do
      it "401を返す" do
        delete "/api/v1/users/#{user.id}", params: { password: "password123" }.to_json,
               headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
