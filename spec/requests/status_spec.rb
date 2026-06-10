require "rails_helper"

RSpec.describe "Status page" do
  it "shows scraper statuses" do
    ScraperRun.create!(scraper: "Treibhaus", status: :success, events_count: 12)
    ScraperRun.create!(scraper: "Brux", status: :failure, error_class: "SocketError", error_message: "connection refused")

    get status_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("OK")
    expect(response.body).to include("FAILING")
    expect(response.body).to include("SocketError: connection refused")
  end

  it "shows weekly visitor counts" do
    Visit.create!(week: Date.current.beginning_of_week, visitor_digest: "abc")
    Visit.create!(week: Date.current.beginning_of_week, visitor_digest: "def")

    get status_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Unique visitors")
  end
end
