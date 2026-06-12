require "base64"

# Montagu publishes its bar programme only as a monthly poster image on
# the Programm page (no structured HTML), so the poster is located in the
# page, downloaded at full resolution and read with the Claude API.
class FetchMontagu
  URL = "https://www.montagu-hostel.com/bar/programm/"
  LOCATION = "Montagu Bar"

  MODEL = :"claude-opus-4-8"

  EVENTS_SCHEMA = {
    type: "object",
    properties: {
      events: {
        type: "array",
        items: {
          type: "object",
          properties: {
            name: { type: "string", description: "Concise event title" },
            datetime: { type: "string", description: "Local start time (Europe/Vienna) as YYYY-MM-DDTHH:MM" },
            description: { type: "string", description: "1-2 German sentences with notable details, empty string if none" },
            category: { type: "string", enum: Event::CATEGORIES, description: "The kind of event" }
          },
          required: %w[name datetime description category],
          additionalProperties: false
        }
      }
    },
    required: %w[events],
    additionalProperties: false
  }.freeze

  def self.call
    events = extract_events(fetch_posters)
    events = events.select { |event| event[:datetime] >= Time.zone.now.beginning_of_day }

    events.each { |event| Event.create(event) }
  end

  # Around the turn of the month the page can show the current and the next
  # month's poster side by side, so all poster images are fetched.
  def self.fetch_posters
    document = Nokogiri::HTML(HTTParty.get(URL).body)
    images = document.css(".content figure.wp-block-image img")
    raise "no programme poster found on #{URL}" if images.empty?

    images.map do |image|
      response = HTTParty.get(URI.join(URL, full_size_url(image)).to_s)
      {
        media_type: response.headers["content-type"].presence || "image/jpeg",
        data: Base64.strict_encode64(response.body)
      }
    end
  end

  # The img src is a downscaled variant; the original is the widest
  # srcset candidate ("/uploads/June-26-print.jpg 900w").
  def self.full_size_url(image)
    candidates = image["srcset"].to_s.split(",").map do |candidate|
      url, width = candidate.strip.split(/\s+/)
      [ url, width.to_i ]
    end

    candidates.max_by(&:last)&.first || image["src"]
  end

  def self.extract_events(posters)
    message = anthropic.messages.create(
      model: MODEL,
      max_tokens: 16000,
      thinking: { type: "adaptive" },
      system_: system_prompt,
      messages: [ {
        role: "user",
        content: posters.map { |poster| { type: "image", source: { type: "base64", **poster } } }
      } ],
      output_config: { format: { type: "json_schema", schema: EVENTS_SCHEMA } }
    )

    json = message.content.find { |block| block.type == :text }&.text
    raise "Claude returned no text content (stop_reason: #{message.stop_reason})" if json.nil?

    JSON.parse(json).fetch("events").map do |event|
      {
        name: event["name"],
        datetime: Time.zone.parse(event["datetime"]),
        description: event["description"].presence,
        category: event["category"],
        location: LOCATION,
        link: URL,
        organization: "Montagu",
        source: :scraper
      }
    end
  end

  def self.system_prompt
    <<~PROMPT
      You extract event listings for an Innsbruck events website from the monthly programme
      poster of the Montagu Bar (a hostel bar at Höttingergasse 7-9, Innsbruck).

      Today is #{Date.current.iso8601}. You receive one or more monthly programme posters
      as images (around the turn of the month both the current and the next month's poster
      can be up). Extract every public event on them.

      Rules:
      - Each poster covers one month; resolve dates using that poster's month heading and
        today's date. Times are local (Europe/Vienna). If an event has no start time, use 20:00.
      - Return ONE entry per real-world event, even if it appears on several posters.
      - name: a concise title; if the event has no name, use the main acts or the format
        (e.g. "Pub Quiz", "Open Mic").
      - description: 1-2 sentences in German with notable details (lineup, genre, entry).
        Empty string if there is nothing to add.
      - category: the kind of event. Theater (plays, performance, improv), Konzerte (live
        music), Party (club nights, DJ sets), Kultur (exhibitions, film, readings, talks,
        markets), Workshop (participatory classes), Politik (demos, political talks),
        Andere (anything else).
      - Skip entries that are not events open to the public (opening hours, food specials).
    PROMPT
  end

  def self.anthropic
    @anthropic ||= Anthropic::Client.new
  end

  private_class_method :fetch_posters, :full_size_url, :extract_events, :system_prompt, :anthropic
end
