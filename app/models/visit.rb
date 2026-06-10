class Visit < ApplicationRecord
  BOT_PATTERN = /bot|crawl|spider|slurp|curl|wget|httpclient|python|scrapy|headless/i

  # Privacy-friendly visit tracking: we never store the IP address, only a
  # SHA256 digest of (secret_key_base, week, ip, user agent). The week in the
  # digest input rotates it weekly, so visitors cannot be tracked across weeks
  # and a digest is worthless once the week is over.
  def self.track(request)
    user_agent = request.user_agent.to_s
    return if user_agent.blank? || user_agent.match?(BOT_PATTERN)

    week = Date.current.beginning_of_week
    digest = Digest::SHA256.hexdigest(
      [ Rails.application.secret_key_base, week.iso8601, request.remote_ip, user_agent ].join("--")
    )

    insert({ week:, visitor_digest: digest })
  end
end
