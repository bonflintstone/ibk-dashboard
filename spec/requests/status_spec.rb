require "rails_helper"

RSpec.describe "Status page" do
  def auth_headers(password = "test-password")
    { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", password) }
  end

  around do |example|
    previous = ENV["ADMIN_PASSWORD"]
    ENV["ADMIN_PASSWORD"] = "test-password"
    example.run
    ENV["ADMIN_PASSWORD"] = previous
  end

  it "requires the admin password" do
    get status_path

    expect(response).to have_http_status(:unauthorized)
  end

  it "shows scraper statuses" do
    ScraperRun.create!(scraper: "Treibhaus", status: :success, events_count: 12)
    ScraperRun.create!(scraper: "Brux", status: :failure, error_class: "SocketError", error_message: "connection refused")

    get status_path, headers: auth_headers

    expect(response).to have_http_status(:success)
    expect(response.body).to include("OK")
    expect(response.body).to include("FAILING")
    expect(response.body).to include("SocketError: connection refused")
  end

  it "lists Instagram organizations as scrapers" do
    InstagramProfile.create!(
      username: "arche.ahoi", organization: "Arche Ahoi", location: "Bogen 30"
    )

    get status_path, headers: auth_headers

    expect(response.body).to include("Arche Ahoi")
  end

  it "shows weekly visitor counts" do
    Visit.create!(week: Date.current.beginning_of_week, visitor_digest: "abc")
    Visit.create!(week: Date.current.beginning_of_week, visitor_digest: "def")

    get status_path, headers: auth_headers

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Unique visitors")
  end

  describe "refetch" do
    it "requires the admin password" do
      post status_refetch_path

      expect(response).to have_http_status(:unauthorized)
    end

    it "enqueues a full refetch" do
      expect do
        post status_refetch_path, headers: auth_headers
      end.to have_enqueued_job(RefetchJob).with(no_args)

      expect(response).to redirect_to(status_path)
    end

    it "enqueues a refetch for a single organization" do
      expect do
        post status_refetch_path(organization: "Treibhaus"), headers: auth_headers
      end.to have_enqueued_job(RefetchJob).with("Treibhaus")
    end

    it "rejects unknown organizations" do
      expect do
        post status_refetch_path(organization: "Hacker"), headers: auth_headers
      end.not_to have_enqueued_job(RefetchJob)

      get response.location, headers: auth_headers
      expect(response.body).to include("Unknown organization")
    end
  end
end
