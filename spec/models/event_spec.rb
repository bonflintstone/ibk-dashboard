require "rails_helper"

RSpec.describe Event do
  describe ".organizations_by_type" do
    it "merges Instagram profile organizations into their category" do
      InstagramProfile.create!(
        username: "arche.ahoi", organization: "Arche Ahoi",
        location: "Bogen 30", category: "Musik und Kultur"
      )

      expect(Event.organizations_by_type[:'Musik und Kultur']).to include("Arche Ahoi", "Treibhaus")
      expect(Event::ORGANIZATIONS_BY_TYPE[:'Musik und Kultur']).not_to include("Arche Ahoi")
    end
  end

  it "accepts events for Instagram profile organizations" do
    InstagramProfile.create!(
      username: "arche.ahoi", organization: "Arche Ahoi",
      location: "Bogen 30", category: "Musik und Kultur"
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
end
