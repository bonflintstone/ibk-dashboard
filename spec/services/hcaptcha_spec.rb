require "rails_helper"

RSpec.describe Hcaptcha do
  around do |example|
    previous = ENV["HCAPTCHA_SECRET_KEY"]
    example.run
    ENV["HCAPTCHA_SECRET_KEY"] = previous
  end

  it "passes when no secret key is configured (development, test)" do
    ENV["HCAPTCHA_SECRET_KEY"] = nil

    expect(Hcaptcha.verify?(nil)).to be(true)
  end

  context "with a configured secret key" do
    before { ENV["HCAPTCHA_SECRET_KEY"] = "secret" }

    it "fails without a captcha token" do
      expect(Hcaptcha.verify?("")).to be(false)
    end

    it "verifies the token against the hCaptcha API" do
      response = double(code: 200)
      allow(response).to receive(:[]).with("success").and_return(true)
      allow(HTTParty).to receive(:post)
        .with(Hcaptcha::VERIFY_URL, body: hash_including(secret: "secret", response: "token"))
        .and_return(response)

      expect(Hcaptcha.verify?("token", remote_ip: "1.2.3.4")).to be(true)
    end

    it "fails when the API rejects the token" do
      response = double(code: 200)
      allow(response).to receive(:[]).with("success").and_return(false)
      allow(HTTParty).to receive(:post).and_return(response)

      expect(Hcaptcha.verify?("token")).to be(false)
    end
  end
end
