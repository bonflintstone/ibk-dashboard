require "rails_helper"

RSpec.describe "Events page" do
  it "renders all upcoming events with filter chips and date navigation" do
    Event.create!(name: "Konzert", location: "Treibhaus", organization: "Treibhaus",
                  datetime: 1.day.from_now, link: "https://example.com", source: :scraper)
    Event.create!(name: "Filmabend", location: "Brux", organization: "Brux",
                  datetime: 2.days.from_now, link: "https://example.com/film", source: :scraper)

    get root_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Konzert").and include("Filmabend")
    expect(response.body).to include("data-controller=\"events\"")
    expect(response.body).to include("data-organization=\"Treibhaus\"")
    expect(response.body).to include("#date-#{1.day.from_now.to_date.iso8601}")
  end
end
