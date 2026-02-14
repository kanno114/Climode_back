require "rails_helper"

RSpec.describe "Api::V1::SessionsController", type: :request do
  include AuthHelper

  let(:user) { create(:user) }
  let(:token) { generate_jwt_token(user) }
  let(:headers) { { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" } }

  describe "GET /api/v1/validate_token" do
    context "with valid access token" do
      it "returns valid: true with user information" do
        get "/api/v1/validate_token", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["valid"]).to be true
        expect(json["user_id"]).to eq(user.id)
        expect(json["email"]).to eq(user.email)
      end
    end

    context "without Authorization header" do
      it "returns valid: false with error message" do
        get "/api/v1/validate_token", headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["valid"]).to be false
        expect(json["error"]).to eq("認証トークンが提供されていません")
      end
    end

    context "with invalid token format" do
      it "returns valid: false with error message" do
        invalid_headers = { "Authorization" => "Bearer invalid_token", "Content-Type" => "application/json" }
        get "/api/v1/validate_token", headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["valid"]).to be false
        expect(json["error"]).to eq("無効な認証トークンです")
      end
    end

    context "with expired token" do
      it "returns valid: false with error message" do
        # 期限切れのトークンを生成（過去の時間でexpを設定）
        expired_payload = {
          user_id: user.id,
          email: user.email,
          exp: (Time.current - 1.hour).to_i,
          iat: (Time.current - 2.hours).to_i,
          type: "access"
        }
        expired_token = JWT.encode(expired_payload, Auth::JwtService::JWT_SECRET, Auth::JwtService::ALGORITHM)
        expired_headers = { "Authorization" => "Bearer #{expired_token}", "Content-Type" => "application/json" }

        get "/api/v1/validate_token", headers: expired_headers

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["valid"]).to be false
        expect(json["error"]).to eq("認証トークンの有効期限が切れています")
      end
    end

    context "with non-access token type" do
      it "returns valid: false with error message" do
        # アクセストークン以外のタイプを手動で構築
        non_access_payload = {
          user_id: user.id,
          email: user.email,
          exp: (Time.current + 1.hour).to_i,
          iat: Time.current.to_i,
          type: "other"
        }
        non_access_token = JWT.encode(non_access_payload, Auth::JwtService::JWT_SECRET, Auth::JwtService::ALGORITHM)
        non_access_headers = { "Authorization" => "Bearer #{non_access_token}", "Content-Type" => "application/json" }

        get "/api/v1/validate_token", headers: non_access_headers

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["valid"]).to be false
        expect(json["error"]).to eq("アクセストークンが必要です")
      end
    end

    context "with token for non-existent user" do
      it "returns valid: false with error message" do
        # 存在しないユーザーIDのトークンを生成
        non_existent_payload = {
          user_id: 999999,
          email: "nonexistent@example.com",
          exp: (Time.current + 15.minutes).to_i,
          iat: Time.current.to_i,
          type: "access"
        }
        non_existent_token = JWT.encode(non_existent_payload, Auth::JwtService::JWT_SECRET, Auth::JwtService::ALGORITHM)
        non_existent_headers = { "Authorization" => "Bearer #{non_existent_token}", "Content-Type" => "application/json" }

        get "/api/v1/validate_token", headers: non_existent_headers

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["valid"]).to be false
        expect(json["error"]).to eq("無効な認証トークンです")
      end
    end

    context "with malformed Authorization header" do
      it "returns valid: false with error message" do
        malformed_headers = { "Authorization" => "InvalidFormat token", "Content-Type" => "application/json" }
        get "/api/v1/validate_token", headers: malformed_headers

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["valid"]).to be false
        expect(json["error"]).to eq("認証トークンが提供されていません")
      end
    end
  end
end
