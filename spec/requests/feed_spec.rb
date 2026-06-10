require "rails_helper"

RSpec.describe "RSS feed" do
  it "renders upcoming published events as RSS" do
    Event.create!(name: "Konzert", location: "Treibhaus", organization: "Treibhaus",
                  datetime: 1.day.from_now, link: "https://example.com/konzert",
                  description: "Ein tolles Konzert", source: :scraper)
    Event.create!(name: "Vergangenes", location: "Treibhaus", organization: "Treibhaus",
                  datetime: 2.days.ago, link: "https://example.com/alt", source: :scraper)
    Event.create!(name: "Unfreigegeben", location: "Irgendwo", organization: "Andere",
                  datetime: 1.day.from_now, link: "https://example.com/neu", source: :webform)

    get feed_path

    expect(response).to have_http_status(:success)
    expect(response.media_type).to eq("application/rss+xml")

    rss = Nokogiri::XML(response.body)
    expect(rss.errors).to be_empty
    expect(rss.at_xpath("/rss/channel/title").text).to eq("Ibk Dashboard")

    items = rss.xpath("/rss/channel/item")
    expect(items.size).to eq(1)
    expect(items.first.at_xpath("title").text).to include("Konzert").and include("Treibhaus")
    expect(items.first.at_xpath("link").text).to eq("https://example.com/konzert")
    expect(items.first.at_xpath("description").text).to eq("Ein tolles Konzert")
    expect(items.first.at_xpath("category").text).to eq("Treibhaus")
  end
end
