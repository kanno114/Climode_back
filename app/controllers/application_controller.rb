class ApplicationController < ActionController::API
  before_action :set_security_headers

  private

  def set_security_headers
    response.set_header("X-Content-Type-Options", "nosniff")
  end
end
