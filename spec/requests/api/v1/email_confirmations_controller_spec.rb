require "rails_helper"

RSpec.describe "Api::V1::EmailConfirmationsController", type: :request do
  include AuthHelper

  before do
    Rack::Attack.enabled = false
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.deliveries.clear
  end

  after do
    Rack::Attack.enabled = true
  end

  describe "POST /api/v1/email_confirmation" do
    let(:user) { create(:user, email_confirmed: false) }
    let(:token) { generate_jwt_token(user) }
    let(:headers) { { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" } }

    context "未確認ユーザーの場合" do
      it "確認メールを送信する" do
        expect {
          post "/api/v1/email_confirmation", headers: headers
        }.to change { ActionMailer::Base.deliveries.count }.by(1)

        expect(response).to have_http_status(:ok)
        json = json_response
        expect(json["message"]).to include("確認メールを送信しました")
      end

      it "確認トークンを生成する" do
        expect {
          post "/api/v1/email_confirmation", headers: headers
        }.to change { user.reload.confirmation_token_digest }
      end
    end

    context "確認済みユーザーの場合" do
      let(:user) { create(:user, email_confirmed: true) }

      it "すでに確認済みのメッセージを返す" do
        post "/api/v1/email_confirmation", headers: headers

        expect(response).to have_http_status(:ok)
        json = json_response
        expect(json["message"]).to include("すでに確認済み")
      end

      it "メールを送信しない" do
        expect {
          post "/api/v1/email_confirmation", headers: headers
        }.not_to change { ActionMailer::Base.deliveries.count }
      end
    end

    context "未認証の場合" do
      it "401を返す" do
        post "/api/v1/email_confirmation", headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PUT /api/v1/email_confirmation" do
    let(:user) { create(:user, email_confirmed: false) }
    let!(:raw_token) { user.generate_confirmation_token! }

    context "有効なトークンの場合" do
      it "メールアドレスを確認済みにする" do
        put "/api/v1/email_confirmation",
            params: { token: raw_token }.to_json,
            headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:ok)
        json = json_response
        expect(json["message"]).to include("メールアドレスが確認されました")

        user.reload
        expect(user.email_confirmed?).to be true
        expect(user.confirmation_token_digest).to be_nil
      end
    end

    context "無効なトークンの場合" do
      it "エラーを返す" do
        put "/api/v1/email_confirmation",
            params: { token: "invalid_token" }.to_json,
            headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unprocessable_entity)
        json = json_response
        expect(json["error"]).to eq("invalid_token")
      end
    end

    context "期限切れトークンの場合" do
      it "エラーを返す" do
        user.update!(confirmation_sent_at: 25.hours.ago)

        put "/api/v1/email_confirmation",
            params: { token: raw_token }.to_json,
            headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unprocessable_entity)
        json = json_response
        expect(json["error"]).to eq("invalid_token")
      end
    end

    context "トークンが空の場合" do
      it "エラーを返す" do
        put "/api/v1/email_confirmation",
            params: { token: "" }.to_json,
            headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unprocessable_entity)
        json = json_response
        expect(json["error"]).to eq("invalid_token")
      end
    end

    context "すでに確認済みのユーザーの場合" do
      it "すでに確認済みのメッセージを返す" do
        user.update!(email_confirmed: true)

        put "/api/v1/email_confirmation",
            params: { token: raw_token }.to_json,
            headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:ok)
        json = json_response
        expect(json["message"]).to include("すでに確認済み")
      end
    end

    context "認証不要で利用できる" do
      it "認証ヘッダーなしでアクセスできる" do
        put "/api/v1/email_confirmation",
            params: { token: raw_token }.to_json,
            headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
