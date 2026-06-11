# Server-side verification for the hCaptcha widget on the event form.
# Without configured keys (development, test) verification passes, so the
# form stays usable locally.
class Hcaptcha
  VERIFY_URL = "https://api.hcaptcha.com/siteverify"

  def self.site_key = ENV["HCAPTCHA_SITE_KEY"]

  def self.configured? = ENV["HCAPTCHA_SECRET_KEY"].present?

  def self.verify?(token, remote_ip: nil)
    return true unless configured?
    return false if token.blank?

    response = HTTParty.post(
      VERIFY_URL,
      body: { secret: ENV["HCAPTCHA_SECRET_KEY"], response: token, remoteip: remote_ip }
    )
    response.code == 200 && response["success"] == true
  end
end
