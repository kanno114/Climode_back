module AuthHelper
  def auth_headers(user)
    {
      'User-Id' => user.id.to_s,
      'Content-Type' => 'application/json'
    }
  end

  def generate_jwt_token(user)
    Auth::JwtService.generate_access_token(user)
  end

  def json_response
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include AuthHelper, type: :request
end
