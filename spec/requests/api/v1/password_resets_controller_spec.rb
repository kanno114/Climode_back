require "rails_helper"

RSpec.describe "Api::V1::PasswordResetsController", type: :request do
  include AuthHelper

  before do
    Rack::Attack.enabled = false
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.deliveries.clear
  end

  after do
    Rack::Attack.enabled = true
  end

  let(:user) { create(:user, email: "user@example.com") }

  describe "POST /api/v1/password_resets" do
    context "登録済みメールアドレスの場合" do
      it "成功レスポンスを返す" do
        post "/api/v1/password_resets",
             params: { password_reset: { email: user.email } }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:ok)
        json = json_response
        expect(json["message"]).to include("メールを送信しました")
      end

      it "リセットトークンを生成する" do
        expect {
          post "/api/v1/password_resets",
               params: { password_reset: { email: user.email } }.to_json,
               headers: { "Content-Type" => "application/json" }
        }.to change { user.reload.reset_password_token_digest }
      end

      it "メールを送信する" do
        expect {
          post "/api/v1/password_resets",
               params: { password_reset: { email: user.email } }.to_json,
               headers: { "Content-Type" => "application/json" }
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end
    end

    context "未登録メールアドレスの場合" do
      it "同じ成功レスポンスを返す（ユーザー列挙防止）" do
        post "/api/v1/password_resets",
             params: { password_reset: { email: "unknown@example.com" } }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:ok)
        json = json_response
        expect(json["message"]).to include("メールを送信しました")
      end
    end

    context "OAuthユーザーの場合" do
      let(:oauth_user) { create(:user, :oauth, email: "oauth@example.com") }

      it "Googleログインを案内する" do
        post "/api/v1/password_resets",
             params: { password_reset: { email: oauth_user.email } }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:ok)
        json = json_response
        expect(json["oauth_provider"]).to be true
        expect(json["message"]).to include("Googleアカウントでログイン")
      end
    end

    context "メールアドレスが空の場合" do
      it "バリデーションエラーを返す" do
        post "/api/v1/password_resets",
             params: { password_reset: { email: "" } }.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe "PUT /api/v1/password_resets/:id" do
    let!(:raw_token) { user.generate_reset_password_token! }

    context "有効なトークンとパスワードの場合" do
      it "パスワードを更新する" do
        put "/api/v1/password_resets/0",
            params: { password_reset: { token: raw_token, password: "newpassword123", password_confirmation: "newpassword123" } }.to_json,
            headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:ok)
        json = json_response
        expect(json["message"]).to include("パスワードが正常に更新されました")

        # 新しいパスワードでログインできることを確認
        expect(user.reload.authenticate("newpassword123")).to be_truthy
      end

      it "トークンを無効化する" do
        put "/api/v1/password_resets/0",
            params: { password_reset: { token: raw_token, password: "newpassword123", password_confirmation: "newpassword123" } }.to_json,
            headers: { "Content-Type" => "application/json" }

        user.reload
        expect(user.reset_password_token_digest).to be_nil
        expect(user.reset_password_sent_at).to be_nil
      end
    end

    context "無効なトークンの場合" do
      it "エラーを返す" do
        put "/api/v1/password_resets/0",
            params: { password_reset: { token: "invalid_token", password: "newpassword123", password_confirmation: "newpassword123" } }.to_json,
            headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unprocessable_entity)
        json = json_response
        expect(json["error"]).to eq("invalid_token")
      end
    end

    context "期限切れトークンの場合" do
      it "エラーを返す" do
        user.update!(reset_password_sent_at: 2.hours.ago)

        put "/api/v1/password_resets/0",
            params: { password_reset: { token: raw_token, password: "newpassword123", password_confirmation: "newpassword123" } }.to_json,
            headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unprocessable_entity)
        json = json_response
        expect(json["error"]).to eq("invalid_token")
      end
    end

    context "パスワードが一致しない場合" do
      it "エラーを返す" do
        put "/api/v1/password_resets/0",
            params: { password_reset: { token: raw_token, password: "newpassword123", password_confirmation: "different123" } }.to_json,
            headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unprocessable_entity)
        json = json_response
        expect(json["message"]).to include("一致しません")
      end
    end

    context "パスワードが短すぎる場合" do
      it "エラーを返す" do
        put "/api/v1/password_resets/0",
            params: { password_reset: { token: raw_token, password: "short", password_confirmation: "short" } }.to_json,
            headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "トークンが空の場合" do
      it "エラーを返す" do
        put "/api/v1/password_resets/0",
            params: { password_reset: { token: "", password: "newpassword123", password_confirmation: "newpassword123" } }.to_json,
            headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unprocessable_entity)
        json = json_response
        expect(json["error"]).to eq("invalid_token")
      end
    end
  end
end
