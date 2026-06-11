require "rails_helper"

RSpec.describe "Admin" do
  def basic_auth(password)
    { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", password) }
  end

  around do |example|
    previous = ENV["ADMIN_PASSWORD"]
    ENV["ADMIN_PASSWORD"] = "test-password"
    example.run
    ENV["ADMIN_PASSWORD"] = previous
  end

  it "rejects requests without credentials" do
    get "/admin"

    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects requests with a wrong password" do
    get "/admin", headers: basic_auth("wrong")

    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects all requests when no password is configured" do
    ENV["ADMIN_PASSWORD"] = nil

    get "/admin", headers: basic_auth("")

    expect(response).to have_http_status(:unauthorized)
  end

  it "allows requests with the password" do
    get "/admin", headers: basic_auth("test-password")

    expect(response).to have_http_status(:ok)
  end
end
