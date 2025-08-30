class Api::V1::AuthController < ApplicationController

  def signup
    user_params = params.require(:user).permit(:name, :email, :password, :password_confirmation)
    user = User.new(user_params)

    if user.save
      render json: { id: user.id, email: user.email, name: user.name }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def signin
    user_params = params.require(:user).permit(:email, :password)
    user = User.find_by(email: user_params[:email])

    if user&.authenticate(user_params[:password])
      render json: { id: user.id, email: user.email, name: user.name }, status: :ok
    else
      render json: { errors: ["メールアドレスまたはパスワードが正しくありません"] }, status: :unauthorized
    end
  end

  def oauth_register
    user_params = params.require(:user).permit(:email, :name, :image, :provider)
    user = User.find_or_initialize_by(email: user_params[:email])
    user.assign_attributes(user_params)

    if user.save(validate: false)
      render json: { id: user.id, email: user.email, name: user.name }, status: :ok
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end
end


