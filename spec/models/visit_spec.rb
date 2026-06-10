require "rails_helper"

RSpec.describe Visit do
  Request = Struct.new(:remote_ip, :user_agent)

  describe ".track" do
    it "counts the same visitor only once per week" do
      request = Request.new("1.2.3.4", "Mozilla/5.0 (Macintosh)")

      expect {
        Visit.track(request)
        Visit.track(request)
      }.to change(Visit, :count).by(1)

      visit = Visit.last
      expect(visit.week).to eq(Date.current.beginning_of_week)
      expect(visit.visitor_digest).not_to include("1.2.3.4")
    end

    it "counts different visitors separately" do
      expect {
        Visit.track(Request.new("1.2.3.4", "Mozilla/5.0 (Macintosh)"))
        Visit.track(Request.new("5.6.7.8", "Mozilla/5.0 (Macintosh)"))
      }.to change(Visit, :count).by(2)
    end

    it "ignores bots and blank user agents" do
      expect {
        Visit.track(Request.new("1.2.3.4", "Googlebot/2.1"))
        Visit.track(Request.new("1.2.3.4", "curl/8.0"))
        Visit.track(Request.new("1.2.3.4", nil))
      }.not_to change(Visit, :count)
    end
  end
end
