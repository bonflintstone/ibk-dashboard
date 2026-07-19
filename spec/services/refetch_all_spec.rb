require "rails_helper"

RSpec.describe RefetchAll do
  before { allow(CategorizeEvents).to receive(:call) }

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

  it "records a success for empty-allowed scrapers returning 0 events" do
    RefetchAll::SCRAPERS.each do |organization, fetcher|
      allow(fetcher).to receive(:call) do
        create_event(organization) unless RefetchAll::EMPTY_ALLOWED.include?(organization)
      end
    end

    RefetchAll.call

    expect(ScraperRun.find_by(scraper: "SNKTBRTLM")).to be_success
    expect(ScraperRun.find_by(scraper: "Gans Anders")).to be_success
  end

  it "records successes when scrapers create events" do
    RefetchAll::SCRAPERS.each do |organization, fetcher|
      allow(fetcher).to receive(:call) { create_event(organization) }
    end

    RefetchAll.call

    expect(ScraperRun.where(status: :success).count).to eq(RefetchAll::SCRAPERS.size)
    expect(RefetchEvent.last.new_event_count).to eq(RefetchAll::SCRAPERS.size)
  end

  it "categorizes new events per organization and sweeps the rest at the end" do
    RefetchAll::SCRAPERS.each do |organization, fetcher|
      allow(fetcher).to receive(:call) { create_event(organization) }
    end

    RefetchAll.call

    # one call per organization plus the final sweep for leftovers
    expect(CategorizeEvents).to have_received(:call).exactly(RefetchAll::SCRAPERS.size + 1).times
  end

  it "keeps the run going when categorization fails" do
    allow(CategorizeEvents).to receive(:call).and_raise("Claude unavailable")
    RefetchAll::SCRAPERS.each do |organization, fetcher|
      allow(fetcher).to receive(:call) { create_event(organization) }
    end

    RefetchAll.call

    expect(ScraperRun.where(status: :success).count).to eq(RefetchAll::SCRAPERS.size)
    expect(RefetchEvent.last).to be_present
  end

  it "runs FetchInstagram for each Instagram profile" do
    profile = InstagramProfile.create!(
      username: "arche.ahoi", organization: "Arche Ahoi", location: "Bogen 30"
    )
    RefetchAll::SCRAPERS.each do |organization, fetcher|
      allow(fetcher).to receive(:call) { create_event(organization) }
    end
    allow(FetchInstagram).to receive(:call).with(profile) { create_event("Arche Ahoi") }

    RefetchAll.call

    expect(FetchInstagram).to have_received(:call).with(profile)
    expect(ScraperRun.find_by(scraper: "Arche Ahoi")).to be_success
  end

  it "pauses between Instagram profiles to avoid rate limiting" do
    %w[arche.ahoi pembau.art].each do |username|
      InstagramProfile.create!(username:, organization: username, location: "Innsbruck")
    end
    RefetchAll::SCRAPERS.each do |organization, fetcher|
      allow(fetcher).to receive(:call) { create_event(organization) }
    end
    allow(FetchInstagram).to receive(:call)
    allow(RefetchAll).to receive(:pause)

    RefetchAll.call

    expect(RefetchAll).to have_received(:pause).once.with(15)
  end

  it "skips Instagram profiles fetched within the last three days" do
    fresh = InstagramProfile.create!(
      username: "arche.ahoi", organization: "Arche Ahoi", location: "Bogen 30",
      fetched_at: 1.day.ago
    )
    due = InstagramProfile.create!(
      username: "pembau.art", organization: "Pembau", location: "Pembau",
      fetched_at: 4.days.ago
    )
    RefetchAll::SCRAPERS.each do |organization, fetcher|
      allow(fetcher).to receive(:call) { create_event(organization) }
    end
    allow(FetchInstagram).to receive(:call)

    RefetchAll.call

    expect(FetchInstagram).to have_received(:call).with(due)
    expect(FetchInstagram).not_to have_received(:call).with(fresh)
    expect(ScraperRun.find_by(scraper: "Arche Ahoi")).to be_nil
  end

  it "records a failure for a profile but continues when FetchInstagram raises" do
    InstagramProfile.create!(
      username: "arche.ahoi", organization: "Arche Ahoi", location: "Bogen 30"
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
