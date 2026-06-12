require "rails_helper"

RSpec.describe "Static pages" do
  it "renders the imprint" do
    get imprint_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Impressum")
  end

  it "renders the privacy policy" do
    get privacy_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Datenschutzerklärung")
    expect(response.body).to include("hCaptcha")
  end

  it "links imprint and privacy policy in the footer" do
    get root_path

    expect(response.body).to include(imprint_path)
    expect(response.body).to include(privacy_path)
  end

  it "does not load the hCaptcha script on regular pages" do
    get root_path

    expect(response.body).not_to include("js.hcaptcha.com")
  end
end
