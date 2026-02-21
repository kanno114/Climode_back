require "rails_helper"

RSpec.describe "Root path", type: :request do
  describe "GET /" do
    it "returns 200" do
      get "/"
      expect(response).to have_http_status(:ok)
    end
  end
end
