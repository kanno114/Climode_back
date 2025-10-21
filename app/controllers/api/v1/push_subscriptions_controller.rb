module Api
  module V1
    class PushSubscriptionsController < ApplicationController
      before_action :authenticate_user!

      # POST /api/v1/push_subscriptions
      def create
        subscription = current_user.push_subscriptions.build(subscription_params)

        if subscription.save
          render json: { message: "Successfully subscribed to push notifications", subscription: subscription }, status: :created
        else
          render json: { errors: subscription.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/push_subscriptions/:id
      def destroy
        subscription = current_user.push_subscriptions.find_by(id: params[:id])

        if subscription
          subscription.destroy
          render json: { message: "Successfully unsubscribed from push notifications" }, status: :ok
        else
          render json: { error: "Subscription not found" }, status: :not_found
        end
      end

      # DELETE /api/v1/push_subscriptions/by_endpoint
      def destroy_by_endpoint
        subscription = current_user.push_subscriptions.find_by(endpoint: params[:endpoint])

        if subscription
          subscription.destroy
          render json: { message: "Successfully unsubscribed from push notifications" }, status: :ok
        else
          render json: { error: "Subscription not found" }, status: :not_found
        end
      end

      # GET /api/v1/push_subscriptions
      def index
        subscriptions = current_user.push_subscriptions
        render json: subscriptions, status: :ok
      end

      private

      def subscription_params
        params.require(:subscription).permit(:endpoint, :p256dh_key, :auth_key)
      end

      def authenticate_user!
        token = request.headers["Authorization"]&.split(" ")&.last
        return render json: { error: "Unauthorized" }, status: :unauthorized unless token

        begin
          decoded = JWT.decode(token, Rails.application.credentials.secret_key_base, true, { algorithm: "HS256" })
          @current_user = User.find(decoded[0]["user_id"])
        rescue JWT::DecodeError, ActiveRecord::RecordNotFound
          render json: { error: "Unauthorized" }, status: :unauthorized
        end
      end

      def current_user
        @current_user
      end
    end
  end
end


