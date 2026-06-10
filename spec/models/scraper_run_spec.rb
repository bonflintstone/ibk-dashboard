require "rails_helper"

RSpec.describe ScraperRun do
  describe ".record" do
    it "stores a success with event count" do
      Event.create!(
        name: "Konzert", location: "Treibhaus", organization: "Treibhaus",
        datetime: 1.day.from_now, link: "https://example.com", source: :scraper
      )

      ScraperRun.record("Treibhaus") { }

      run = ScraperRun.last
      expect(run).to be_success
      expect(run.scraper).to eq("Treibhaus")
      expect(run.events_count).to eq(1)
    end

    it "stores a failure without re-raising" do
      expect {
        ScraperRun.record("Treibhaus") { raise SocketError, "connection refused" }
      }.not_to raise_error

      run = ScraperRun.last
      expect(run).to be_failure
      expect(run.error_class).to eq("SocketError")
      expect(run.error_message).to eq("connection refused")
    end
  end
end
