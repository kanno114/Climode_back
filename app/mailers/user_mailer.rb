class UserMailer < ApplicationMailer
  def reset_password_email(user, raw_token)
    @user = user
    @reset_url = "#{frontend_url}/reset-password?token=#{raw_token}"

    mail(
      to: @user.email,
      subject: "【Climode】パスワードの再設定"
    )
  end

  private

  def frontend_url
    ENV.fetch("FRONTEND_URL", "http://localhost:3000")
  end
end
