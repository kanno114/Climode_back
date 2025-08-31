class Api::V1::RegistrationsController < ApplicationController

  def create
    user = User.new(signup_params)

    if user.save
      render json: { id: user.id, email: user.email, name: user.name, image: user.image }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def oauth_register
    # ユーザーを検索または初期化
    user = User.find_or_initialize_by(email: params[:user][:email])
    user.name = params[:user][:name]
    user.password ||= SecureRandom.urlsafe_base64(16)
    user.image = params[:user][:image]

    # トランザクション内でユーザーとuser_identityを作成
    ActiveRecord::Base.transaction do
      if user.save
        # user_identityを作成
        user_identity = user.user_identities.build(
          provider: params[:user][:provider] || "oauth",
          uid: params[:user][:uid] || SecureRandom.uuid,
          email: params[:user][:email],
          display_name: params[:user][:name],
        )

        if user_identity.save
          render json: { status: "ok", id: user.id }
        else
          raise ActiveRecord::Rollback
          render json: { errors: user_identity.errors.full_messages }, status: :unprocessable_entity
        end
      else
        render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::Rollback
    render json: { errors: ["Failed to create user identity"] }, status: :unprocessable_entity
  end

  private

  def signup_params
    params.require(:user).permit(:email, :password, :password_confirmation, :name, :image)
  end
end