module Api
  module V1
    class PushSubscriptionsController < ApplicationController
      include Authenticatable

      # POST /api/v1/push_subscriptions
      def create
        subscription = current_user.push_subscriptions.build(subscription_params)

        if subscription.save
          render json: { message: "Successfully subscribed to push notifications", subscription: subscription }, status: :created
        else
          render json: { error: "validation_error", message: "通知の登録に失敗しました",
                         details: subscription.errors.messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/push_subscriptions/by_endpoint
      def destroy_by_endpoint
        subscription = current_user.push_subscriptions.find_by(endpoint: params[:endpoint])

        if subscription
          subscription.destroy
          render json: { message: "Successfully unsubscribed from push notifications" }, status: :ok
        else
          render json: { error: "not_found", message: "通知の登録が見つかりません" }, status: :not_found
        end
      end

      private

      def subscription_params
        params.require(:subscription).permit(:endpoint, :p256dh_key, :auth_key)
      end
    end
  end
end
