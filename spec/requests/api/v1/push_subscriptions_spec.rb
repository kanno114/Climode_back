require "rails_helper"

RSpec.describe "Api::V1::PushSubscriptions", type: :request do
  let(:user) { create(:user) }
  let(:token) { generate_jwt_token(user) }
  let(:headers) { { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" } }

  describe "POST /api/v1/push_subscriptions" do
    let(:valid_params) do
      {
        subscription: {
          endpoint: "https://fcm.googleapis.com/fcm/send/test-endpoint",
          p256dh_key: "BNxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
          auth_key: "yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy"
        }
      }
    end

    context "with valid parameters" do
      it "creates a new push subscription" do
        expect {
          post "/api/v1/push_subscriptions", params: valid_params.to_json, headers: headers
        }.to change(PushSubscription, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Successfully subscribed to push notifications")
        expect(json["subscription"]["endpoint"]).to eq(valid_params[:subscription][:endpoint])
      end
    end

    context "with invalid parameters" do
      it "returns an error when endpoint is missing" do
        invalid_params = { subscription: { p256dh_key: "test", auth_key: "test" } }

        post "/api/v1/push_subscriptions", params: invalid_params.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["errors"]).to be_present
      end
    end

    context "with duplicate endpoint" do
      before do
        create(:push_subscription, user: user, endpoint: valid_params[:subscription][:endpoint])
      end

      it "returns an error" do
        post "/api/v1/push_subscriptions", params: valid_params.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["errors"]).to include(match(/Endpoint has already been taken/))
      end
    end

    context "without authentication" do
      it "returns unauthorized" do
        post "/api/v1/push_subscriptions", params: valid_params.to_json, headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/push_subscriptions/by_endpoint" do
    let!(:subscription) { create(:push_subscription, user: user) }

    context "with valid endpoint" do
      it "deletes the subscription" do
        expect {
          delete "/api/v1/push_subscriptions/by_endpoint",
                 params: { endpoint: subscription.endpoint }.to_json,
                 headers: headers
        }.to change(PushSubscription, :count).by(-1)

        expect(response).to have_http_status(:ok)
      end
    end

    context "with invalid endpoint" do
      it "returns not found" do
        delete "/api/v1/push_subscriptions/by_endpoint",
               params: { endpoint: "https://invalid-endpoint.com" }.to_json,
               headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
