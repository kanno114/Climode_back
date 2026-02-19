class Api::V1::RegistrationsController < ApplicationController
  def create
    user = User.new(signup_params)

    if user.save
      # メール確認トークンを生成して確認メールを送信
      raw_token = user.generate_confirmation_token!
      UserMailer.confirmation_email(user, raw_token).deliver_later

      access_token = Auth::JwtService.generate_access_token(user)

      render json: {
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          image: user.image || nil,
          email_confirmed: user.email_confirmed?
        },
        access_token: access_token,
        expires_in: Auth::JwtService::ACCESS_TOKEN_EXPIRY,
        is_new_user: true
      }, status: :created
    else
      render json: { error: "validation_error", message: "登録内容に誤りがあります",
                     details: user.errors.messages }, status: :unprocessable_entity
    end
  end

  def oauth_register
    # ユーザーを検索または初期化
    user = User.find_or_initialize_by(email: params[:user][:email])
    was_new_user = user.new_record?
    user.name = params[:user][:name]
    user.password ||= SecureRandom.urlsafe_base64(16)
    user.image = params[:user][:image]
    user.email_confirmed = true

    ActiveRecord::Base.transaction do
      user.save!

      # 既存のアイデンティティがあれば再作成しない
      user_identity = user.user_identities.find_by(
        provider: params[:user][:provider] || "oauth",
        uid: params[:user][:uid]
      )

      created_identity = false
      unless user_identity
        user_identity = user.user_identities.create!(
          provider: params[:user][:provider] || "oauth",
          uid: params[:user][:uid] || SecureRandom.uuid,
          email: params[:user][:email],
          display_name: params[:user][:name]
        )
        created_identity = true
      end

      access_token = Auth::JwtService.generate_access_token(user)
      is_new_user = was_new_user || created_identity

      render json: {
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          image: user.image || nil,
          email_confirmed: user.email_confirmed?
        },
        access_token: access_token,
        expires_in: Auth::JwtService::ACCESS_TOKEN_EXPIRY,
        is_new_user: is_new_user
      }, status: :created
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: "validation_error", message: e.message,
                   details: e.record.errors.messages }, status: :unprocessable_entity
  end

  private

  def signup_params
    params.require(:user).permit(:email, :password, :password_confirmation, :name, :image, :prefecture_id)
  end
end
