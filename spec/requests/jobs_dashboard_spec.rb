require "rails_helper"

RSpec.describe "Jobs dashboard" do
  it "requires the admin password" do
    get "/jobs"

    expect(response).to have_http_status(:unauthorized)
  end
end
