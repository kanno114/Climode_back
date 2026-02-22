class Api::V1::EmailConfirmationsController < ApplicationController
  include Authenticatable

  skip_before_action :authenticate_user!, only: :update

  # POST /api/v1/email_confirmations — 確認メール再送信
  def create
    user = current_user

    if user.email_confirmed?
      render json: { message: "メールアドレスはすでに確認済みです" }, status: :ok
      return
    end

    raw_token = user.generate_confirmation_token!
    UserMailer.confirmation_email(user, raw_token).deliver_now

    render json: { message: "確認メールを送信しました。メールをご確認ください。" }, status: :ok
  end

  # PUT /api/v1/email_confirmations — メール確認の実行
  def update
    token = params[:token]

    if token.blank?
      render json: { error: "invalid_token", message: "確認トークンが無効です" },
             status: :unprocessable_entity
      return
    end

    user = User.find_by_confirmation_token(token)

    if user.nil? || !user.confirmation_token_valid?
      render json: { error: "invalid_token", message: "確認リンクが無効または期限切れです。確認メールを再送信してください。" },
             status: :unprocessable_entity
      return
    end

    if user.email_confirmed?
      render json: { message: "メールアドレスはすでに確認済みです" }, status: :ok
      return
    end

    user.confirm_email!
    render json: { message: "メールアドレスが確認されました" }, status: :ok
  end
end
