class Api::V1::PasswordResetsController < ApplicationController
  # POST /api/v1/password_resets — リセットメール送信
  def create
    email = params.dig(:password_reset, :email)&.downcase&.strip

    if email.blank?
      render json: { error: "parameter_missing", message: "メールアドレスを入力してください" },
             status: :bad_request
      return
    end

    user = User.find_by(email: email)

    if user
      if user.oauth_provider?
        # OAuthユーザーにはGoogleログインを案内（UX向上のため明示する）
        render json: {
          message: "このアカウントはGoogleログインで登録されています。Googleアカウントでログインしてください。",
          oauth_provider: true
        }, status: :ok
        return
      end

      raw_token = user.generate_reset_password_token!
      UserMailer.reset_password_email(user, raw_token).deliver_now
    end

    # ユーザー列挙防止: 存在有無に関わらず同じレスポンス
    render json: { message: "パスワードリセットのメールを送信しました。メールをご確認ください。" }, status: :ok
  end

  # PUT /api/v1/password_resets — パスワード再設定
  def update
    token = params.dig(:password_reset, :token)
    password = params.dig(:password_reset, :password)
    password_confirmation = params.dig(:password_reset, :password_confirmation)

    if token.blank?
      render json: { error: "invalid_token", message: "リセットトークンが無効です" },
             status: :unprocessable_entity
      return
    end

    if password.blank?
      render json: { error: "validation_error", message: "新しいパスワードを入力してください" },
             status: :unprocessable_entity
      return
    end

    if password != password_confirmation
      render json: { error: "validation_error", message: "パスワードが一致しません" },
             status: :unprocessable_entity
      return
    end

    user = User.find_by_reset_token(token)

    if user.nil? || !user.reset_password_token_valid?
      render json: { error: "invalid_token", message: "リセットトークンが無効または期限切れです。再度パスワードリセットを申請してください。" },
             status: :unprocessable_entity
      return
    end

    user.reset_password!(password)
    render json: { message: "パスワードが正常に更新されました。新しいパスワードでログインしてください。" }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: "validation_error", message: e.record.errors.full_messages.join(", ") },
           status: :unprocessable_entity
  end
end
