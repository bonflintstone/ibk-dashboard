require "rails_helper"

RSpec.describe Event do
  describe ".organizations" do
    it "includes the static organizations and Instagram profile organizations" do
      InstagramProfile.create!(
        username: "arche.ahoi", organization: "Arche Ahoi", location: "Bogen 30"
      )

      expect(Event.organizations).to include("Treibhaus", "Arche Ahoi")
    end
  end

  it "accepts events for Instagram profile organizations" do
    InstagramProfile.create!(
      username: "arche.ahoi", organization: "Arche Ahoi", location: "Bogen 30"
    )

    event = Event.new(
      name: "Groove Harbor", location: "Bogen 30", organization: "Arche Ahoi",
      datetime: 1.day.from_now, link: "https://example.com", source: :scraper
    )

    expect(event).to be_valid
  end

  it "rejects events for unknown organizations" do
    event = Event.new(
      name: "Event", location: "Ort", organization: "Unbekannt",
      datetime: 1.day.from_now, link: "https://example.com", source: :scraper
    )

    expect(event).not_to be_valid
  end

  describe "category" do
    def build_event(category:)
      Event.new(
        name: "Event", location: "Treibhaus", organization: "Treibhaus",
        datetime: 1.day.from_now, link: "https://example.com", source: :scraper,
        category:
      )
    end

    it "accepts known categories and nil (not yet categorized)" do
      expect(build_event(category: "Konzerte")).to be_valid
      expect(build_event(category: nil)).to be_valid
    end

    it "rejects unknown categories" do
      expect(build_event(category: "Sport")).not_to be_valid
    end

    it "displays uncategorized events as Andere" do
      expect(build_event(category: nil).display_category).to eq("Andere")
      expect(build_event(category: "Party").display_category).to eq("Party")
    end
  end

  describe "datetime guard" do
    def build_submission(source:, datetime:)
      Event.new(name: "Event", location: "Treibhaus", organization: "Treibhaus",
                link: "https://example.com", source:, datetime:)
    end

    it "rejects past datetimes from the webform" do
      expect(build_submission(source: :webform, datetime: 1.day.ago)).not_to be_valid
    end

    it "accepts future datetimes from the webform" do
      expect(build_submission(source: :webform, datetime: 1.day.from_now)).to be_valid
    end

    it "lets scrapers import events on their start day" do
      expect(build_submission(source: :scraper, datetime: 1.day.ago)).to be_valid
    end
  end
end
