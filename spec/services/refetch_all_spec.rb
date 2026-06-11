require "rails_helper"

RSpec.describe RefetchAll do
  def create_event(organization, name: "Event #{organization}")
    Event.create!(
      name:, location: organization, organization:,
      datetime: 1.day.from_now, link: "https://example.com", source: :scraper
    )
  end

  it "records a failure and keeps the old events when a scraper returns 0 events" do
    old_event = create_event("Treibhaus", name: "Altes Event")
    RefetchAll::SCRAPERS.each_value { |fetcher| allow(fetcher).to receive(:call) }

    RefetchAll.call

    run = ScraperRun.find_by(scraper: "Treibhaus")
    expect(run).to be_failure
    expect(run.error_message).to include("0 events")
    expect(Event.exists?(old_event.id)).to be(true)
  end

  it "records successes when scrapers create events" do
    RefetchAll::SCRAPERS.each do |organization, fetcher|
      allow(fetcher).to receive(:call) { create_event(organization) }
    end

    RefetchAll.call

    expect(ScraperRun.where(status: :success).count).to eq(RefetchAll::SCRAPERS.size)
    expect(RefetchEvent.last.new_event_count).to eq(RefetchAll::SCRAPERS.size)
  end

  it "runs FetchInstagram for each Instagram profile" do
    profile = InstagramProfile.create!(
      username: "arche.ahoi", organization: "Arche Ahoi",
      location: "Bogen 30", category: "Musik und Kultur"
    )
    RefetchAll::SCRAPERS.each do |organization, fetcher|
      allow(fetcher).to receive(:call) { create_event(organization) }
    end
    allow(FetchInstagram).to receive(:call).with(profile) { create_event("Arche Ahoi") }

    RefetchAll.call

    expect(FetchInstagram).to have_received(:call).with(profile)
    expect(ScraperRun.find_by(scraper: "Arche Ahoi")).to be_success
  end

  it "records a failure for a profile but continues when FetchInstagram raises" do
    InstagramProfile.create!(
      username: "arche.ahoi", organization: "Arche Ahoi",
      location: "Bogen 30", category: "Musik und Kultur"
    )
    RefetchAll::SCRAPERS.each do |organization, fetcher|
      allow(fetcher).to receive(:call) { create_event(organization) }
    end
    allow(FetchInstagram).to receive(:call).and_raise("Instagram responded with 403")

    RefetchAll.call

    expect(ScraperRun.find_by(scraper: "Arche Ahoi")).to be_failure
    expect(RefetchEvent.last).to be_present
  end
end
