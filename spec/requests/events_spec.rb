require "rails_helper"

RSpec.describe "Events page" do
  it "renders all upcoming events with filter nav, bookmark toggles and date navigation" do
    konzert = Event.create!(name: "Konzert", location: "Treibhaus", organization: "Treibhaus",
                            datetime: 1.day.from_now, link: "https://example.com", source: :scraper,
                            category: "Konzerte")
    Event.create!(name: "Filmabend", location: "Brux", organization: "Brux",
                  datetime: 2.days.from_now, link: "https://example.com/film", source: :scraper,
                  category: "Kultur")

    get root_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Konzert").and include("Filmabend")
    expect(response.body).to include("data-controller=\"events\"")
    expect(response.body).to include("data-category=\"Konzerte\"").and include("data-category=\"Kultur\"")
    expect(response.body).to include("data-organization=\"Treibhaus\"")
    expect(response.body).to include(">Alle<").and include("Kategorie").and include("Venue").and include(">Gemerkt<")
    expect(response.body).to include("data-bookmark-key=\"Konzert|#{konzert.datetime.iso8601}|Treibhaus\"")
    expect(response.body).to include("events#toggleBookmark")
    expect(response.body).to include("#date-#{1.day.from_now.to_date.iso8601}")
  end

  it "shows uncategorized events under Andere" do
    Event.create!(name: "Frisch gescraped", location: "Treibhaus", organization: "Treibhaus",
                  datetime: 1.day.from_now, link: "https://example.com", source: :scraper)

    get root_path

    expect(response.body).to include("data-category=\"Andere\"")
  end

  it "renders the new-event modal in the footer" do
    get root_path

    expect(response.body).to include("Event eintragen")
    expect(response.body).to include("data-controller=\"modal\"")
    expect(response.body).to include("<dialog")
  end

  describe "submitting an event" do
    def valid_params
      { event: { name: "Impro-Abend", location: "Bogen 30", link: "https://example.com",
                 datetime: 1.day.from_now.iso8601, description: "" } }
    end

    it "creates an unapproved event and enqueues the AI review" do
      expect do
        post events_path, params: valid_params
      end.to change(Event, :count).by(1).and have_enqueued_job(ReviewEventJob)

      event = Event.last
      expect(event).to have_attributes(source: "webform", organization: "Andere", approved_at: nil)
      expect(response).to redirect_to(root_path)
    end

    it "rejects the submission when the captcha fails" do
      allow(Hcaptcha).to receive(:verify?).and_return(false)

      expect do
        post events_path, params: valid_params
      end.not_to change(Event, :count)

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include("Captcha")
    end

    it "re-renders the form for invalid submissions" do
      post events_path, params: { event: { name: "", location: "", link: "", datetime: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Event.count).to eq(0)
    end

    it "rejects submissions with a past date" do
      post events_path, params: { event: { name: "Altes Event", location: "Bogen 30",
                                           link: "https://example.com", datetime: 1.day.ago.iso8601 } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Event.count).to eq(0)
    end
  end

  describe "extracting fields from a link" do
    it "returns the extracted fields as JSON" do
      allow(ExtractEventFromLink).to receive(:call).with("https://treibhaus.at/x")
        .and_return("name" => "Konzert", "location" => "Treibhaus", "datetime" => "", "description" => "")

      post extract_events_path, params: { link: "https://treibhaus.at/x" }, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include("name" => "Konzert", "location" => "Treibhaus")
    end

    it "returns an error when extraction fails" do
      allow(ExtractEventFromLink).to receive(:call).and_raise("boom")

      post extract_events_path, params: { link: "https://x.test" }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to be_present
    end
  end
end
