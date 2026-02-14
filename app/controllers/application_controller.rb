class ApplicationController < ActionController::API
  before_action :set_security_headers

  # グローバルエラーハンドリング（宣言順: 汎用→具体的。後に書いたものが先にマッチ）
  rescue_from StandardError do |e|
    Rails.logger.error "[UnhandledError] #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace&.first(20)&.join("\n")
    render json: { error: "internal_error", message: "サーバーエラーが発生しました" },
           status: :internal_server_error
  end

  rescue_from ActionController::ParameterMissing do |e|
    render json: { error: "parameter_missing", message: e.message },
           status: :bad_request
  end

  rescue_from ActiveRecord::RecordInvalid do |e|
    render json: { error: "validation_error", message: e.message,
                   details: e.record.errors.messages },
           status: :unprocessable_entity
  end

  rescue_from ActiveRecord::RecordNotFound do |e|
    render json: { error: "not_found", message: "リソースが見つかりません" },
           status: :not_found
  end

  private

  def set_security_headers
    response.set_header("X-Content-Type-Options", "nosniff")
  end
end
