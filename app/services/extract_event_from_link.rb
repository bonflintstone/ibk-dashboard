# Fetches an event page and extracts the form fields with the Claude API, so a
# submitter can paste a link and have the rest filled in (and then correct it).
# Returns a hash of strings shaped for the new-event form; missing fields come
# back as empty strings. Raises on a fetch failure or an unusable response.
class ExtractEventFromLink
  MODEL = :"claude-opus-4-8"
  MAX_CHARS = 12_000
  USER_AGENT = "Mozilla/5.0 (compatible; IbkDashboard/1.0; +https://ibk-dashboard.at)"

  FIELDS_SCHEMA = {
    type: "object",
    properties: {
      name: { type: "string", description: "Concise event title, empty string if not found" },
      location: { type: "string", description: "Venue / address, empty string if not found" },
      datetime: { type: "string", description: "Local start time (Europe/Vienna) as YYYY-MM-DDTHH:MM, empty string if not found" },
      description: { type: "string", description: "1-2 German sentences with notable details, empty string if none" }
    },
    required: %w[name location datetime description],
    additionalProperties: false
  }.freeze

  def self.call(url)
    url = normalize_url(url)
    text = fetch_text(url)

    message = anthropic.messages.create(
      model: MODEL,
      max_tokens: 16000,
      thinking: { type: "adaptive" },
      system_: system_prompt,
      messages: [ { role: "user", content: "Event page #{url}\n\n#{text}" } ],
      output_config: { format: { type: "json_schema", schema: FIELDS_SCHEMA } }
    )

    json = message.content.find { |block| block.type == :text }&.text
    raise "Claude returned no text content (stop_reason: #{message.stop_reason})" if json.nil?

    JSON.parse(json).slice("name", "location", "datetime", "description")
  end

  def self.normalize_url(url)
    url = "https://#{url}" unless url.to_s.match?(%r{\Ahttps?://}i)
    uri = URI.parse(url)
    raise "Unsupported URL" unless uri.is_a?(URI::HTTP) && uri.host.present?

    uri.to_s
  rescue URI::InvalidURIError
    raise "Unsupported URL"
  end

  def self.fetch_text(url)
    response = HTTParty.get(url, headers: { "User-Agent" => USER_AGENT }, follow_redirects: true, timeout: 15)
    raise "Could not load the page (#{response.code})" unless response.code == 200

    document = Nokogiri::HTML(response.body)
    document.css("script, style, nav, footer, header, noscript, svg").remove
    title = document.at_css("title")&.text.to_s.strip
    body = document.css("body").text.gsub(/\s+/, " ").strip
    "#{title}\n\n#{body}".first(MAX_CHARS)
  end

  def self.system_prompt
    <<~PROMPT
      You extract a single event's details from the text of an event web page,
      for the submission form of an Innsbruck events website.

      Today is #{Date.current.iso8601}. Times are local (Europe/Vienna).

      Return these fields, using an empty string when the page does not state one:
      - name: a concise event title.
      - location: the venue or address.
      - datetime: the start as YYYY-MM-DDTHH:MM. Resolve relative dates against today.
        If a date but no time is given, use 20:00. Pick the next upcoming date if several.
      - description: 1-2 German sentences with notable details (lineup, genre, entry rules).

      If the page describes several events, extract the most prominent upcoming one.
    PROMPT
  end

  def self.anthropic
    @anthropic ||= Anthropic::Client.new
  end

  private_class_method :normalize_url, :fetch_text, :system_prompt, :anthropic
end
