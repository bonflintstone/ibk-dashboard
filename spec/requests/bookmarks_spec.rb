require "rails_helper"

RSpec.describe "Bookmarks API" do
  def keys_of(list) = list.reload.keys.sort

  describe "GET /bookmarks" do
    it "returns the list's keys" do
      list = BookmarkList.create!
      list.bookmarks.create!(event_key: "Konzert|2026-06-17T20:00:00+02:00|Treibhaus")

      get bookmarks_path, params: { token: list.token }

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to eq(
        "token" => list.token,
        "keys" => [ "Konzert|2026-06-17T20:00:00+02:00|Treibhaus" ]
      )
    end

    it "404s for an unknown token" do
      get bookmarks_path, params: { token: "nope" }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /bookmarks" do
    it "creates a list seeded with the added keys when there is no token" do
      patch bookmarks_path, params: { add: [ "a", "b" ] }, as: :json

      token = response.parsed_body["token"]
      expect(BookmarkList.find_by(token: token).keys.sort).to eq(%w[a b])
      expect(response.parsed_body["keys"].sort).to eq(%w[a b])
    end

    it "adds and removes keys on an existing list, ignoring duplicates" do
      list = BookmarkList.create!
      list.bookmarks.create!(event_key: "a")
      list.bookmarks.create!(event_key: "b")

      patch bookmarks_path, params: { token: list.token, add: [ "b", "c" ], remove: [ "a" ] }, as: :json

      expect(keys_of(list)).to eq(%w[b c])
    end

    it "creates a fresh list for an unknown token" do
      patch bookmarks_path, params: { token: "stale", add: [ "a" ] }, as: :json

      expect(response.parsed_body["token"]).not_to eq("stale")
      expect(response.parsed_body["keys"]).to eq([ "a" ])
    end
  end

  describe "POST /bookmarks/merge" do
    it "pours the source list into the target and removes the source" do
      target = BookmarkList.create!
      target.bookmarks.create!(event_key: "a")
      source = BookmarkList.create!
      source.bookmarks.create!(event_key: "b")

      post merge_bookmarks_path, params: { token: source.token, other: target.token }, as: :json

      expect(response.parsed_body["token"]).to eq(target.token)
      expect(response.parsed_body["keys"].sort).to eq(%w[a b])
      expect(BookmarkList.exists?(token: source.token)).to be(false)
    end

    it "adopts the target as-is when the device has no list of its own" do
      target = BookmarkList.create!
      target.bookmarks.create!(event_key: "a")

      post merge_bookmarks_path, params: { other: target.token }, as: :json

      expect(response.parsed_body).to eq("token" => target.token, "keys" => [ "a" ])
    end

    it "is a no-op when both tokens point to the same list" do
      list = BookmarkList.create!
      list.bookmarks.create!(event_key: "a")

      post merge_bookmarks_path, params: { token: list.token, other: list.token }, as: :json

      expect(response.parsed_body["keys"]).to eq([ "a" ])
      expect(BookmarkList.exists?(token: list.token)).to be(true)
    end

    it "404s for an unknown target token" do
      post merge_bookmarks_path, params: { other: "nope" }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /bookmarks/calendar" do
    include ActiveSupport::Testing::TimeHelpers

    # The examples pin the event date (the DTSTART assertion depends on it),
    # so the clock is pinned too — webform events must not lie in the past.
    before { travel_to Time.zone.local(2026, 6, 10, 12, 0) }
    after { travel_back }

    def create_event(attributes = {})
      Event.create!({ name: "Konzert", location: "Treibhaus", organization: "Treibhaus",
                      datetime: Time.zone.local(2026, 6, 17, 20), link: "https://example.com/konzert",
                      source: :scraper }.merge(attributes))
    end

    it "renders the bookmarked events as an iCalendar feed" do
      bookmarked = create_event(description: "Mit Special Guest, danach Party; yay")
      create_event(name: "Nicht gemerkt")
      list = BookmarkList.create!
      list.bookmarks.create!(event_key: bookmarked.bookmark_key)

      get calendar_bookmarks_path(format: :ics), params: { token: list.token }

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("text/calendar")
      expect(response.body).to start_with("BEGIN:VCALENDAR")
      expect(response.body).to include("SUMMARY:Konzert")
      expect(response.body).to include("DTSTART:20260617T180000Z") # 20:00 Berlin = 18:00 UTC
      expect(response.body).to include("Mit Special Guest\\, danach Party\\; yay")
      expect(response.body).not_to include("Nicht gemerkt")
    end

    it "skips bookmarks of unpublished or since-deleted events" do
      unapproved = create_event(name: "Unfreigegeben", source: :webform)
      list = BookmarkList.create!
      list.bookmarks.create!(event_key: unapproved.bookmark_key)
      list.bookmarks.create!(event_key: "Geloescht|2026-06-17T20:00:00+02:00|Treibhaus")

      get calendar_bookmarks_path(format: :ics), params: { token: list.token }

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("BEGIN:VEVENT")
    end

    it "404s for an unknown token" do
      get calendar_bookmarks_path(format: :ics), params: { token: "nope" }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /bookmarks/qr" do
    it "renders an SVG QR code of the sync link" do
      list = BookmarkList.create!

      get qr_bookmarks_path, params: { token: list.token }

      expect(response.media_type).to eq("image/svg+xml")
      expect(response.body).to include("<svg")
    end

    it "404s for an unknown token" do
      get qr_bookmarks_path, params: { token: "nope" }

      expect(response).to have_http_status(:not_found)
    end
  end
end
