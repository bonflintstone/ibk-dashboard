require "digest"
require "base64"

# Fetches the latest posts of an InstagramProfile via Instagram's public
# web endpoint and extracts upcoming events from captions and flyer images
# with the Claude API. One API call per profile sees all posts at once, so
# events announced in several posts (monthly program + dedicated post) are
# merged into a single entry by the model.
class FetchInstagram
  PROFILE_URL = "https://www.instagram.com/api/v1/users/web_profile_info/"
  # Public app id Instagram's own web client sends; required for the endpoint to respond.
  APP_ID = "936619743392459"
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"

  MODEL = :"claude-opus-4-8"
  MAX_ATTEMPTS = 3

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
            location: { type: "string", description: "Venue where the event takes place" },
            description: { type: "string", description: "1-2 German sentences with notable details, empty string if none" },
            link: { type: "string", description: "URL of the Instagram post announcing this event most specifically" },
            category: { type: "string", enum: Event::CATEGORIES, description: "The kind of event" }
          },
          required: %w[name datetime location description link category],
          additionalProperties: false
        }
      }
    },
    required: %w[events],
    additionalProperties: false
  }.freeze

  def self.call(profile)
    posts = fetch_posts(profile.username)
    digest = Digest::SHA256.hexdigest(posts.to_json)

    # Skip the (paid) extraction when the profile hasn't posted anything
    # new since the last successful run. Clear posts_digest to force one.
    return if digest == profile.posts_digest

    events = extract_events(posts, profile)
    events = events.select { |event| event[:datetime] >= Time.zone.now.beginning_of_day }

    # An empty result is legitimate (e.g. only recap posts). Old events are
    # kept rather than wiped, so a model hiccup can't empty the organization.
    if events.any?
      Event.transaction do
        Event.where(source: :scraper, organization: profile.organization).destroy_all
        events.each { |event| Event.create(event) }
      end
    end

    profile.update!(posts_digest: digest)
  end

  def self.fetch_posts(username)
    response = nil
    MAX_ATTEMPTS.times do |attempt|
      response = HTTParty.get(
        PROFILE_URL,
        query: { username: },
        headers: { "x-ig-app-id" => APP_ID, "User-Agent" => USER_AGENT }
      )
      break unless response.code == 429 && attempt < MAX_ATTEMPTS - 1

      # Rate limited — back off and retry before giving up.
      pause((response.headers["retry-after"].presence || 30).to_i * (attempt + 1))
    end
    raise "Instagram responded with #{response.code}" unless response.code == 200

    edges = JSON.parse(response.body).dig("data", "user", "edge_owner_to_timeline_media", "edges")
    raise "Instagram response contained no posts" if edges.blank?

    edges.map do |edge|
      node = edge["node"]
      {
        url: "https://www.instagram.com/p/#{node["shortcode"]}/",
        published_on: Time.zone.at(node["taken_at_timestamp"]).to_date,
        caption: node.dig("edge_media_to_caption", "edges").first&.dig("node", "text").to_s,
        image_url: node["display_url"]
      }
    end
  end

  def self.extract_events(posts, profile)
    message = anthropic.messages.create(
      model: MODEL,
      max_tokens: 16000,
      thinking: { type: "adaptive" },
      system_: system_prompt(profile),
      messages: [ { role: "user", content: posts.flat_map { |post| post_blocks(post) } } ],
      output_config: { format: { type: "json_schema", schema: EVENTS_SCHEMA } }
    )

    json = message.content.find { |block| block.type == :text }&.text
    raise "Claude returned no text content (stop_reason: #{message.stop_reason})" if json.nil?

    JSON.parse(json).fetch("events").map do |event|
      {
        name: event["name"],
        datetime: Time.zone.parse(event["datetime"]),
        location: event["location"].presence || profile.location,
        description: event["description"].presence,
        link: event["link"].presence || profile.url,
        category: event["category"],
        organization: profile.organization,
        source: :scraper
      }
    end
  end

  def self.system_prompt(profile)
    <<~PROMPT
      You extract event listings for an Innsbruck events website from a venue's recent Instagram posts.

      Today is #{Date.current.iso8601}. The venue: #{profile.organization}, located at #{profile.location}, Innsbruck.

      You receive the venue's latest posts, each with its publish date, post URL, caption, and image
      (often an event flyer or a monthly program). Extract every upcoming public event (today or later).

      Rules:
      - Use both caption and image; flyers often contain details the caption omits.
      - Resolve relative or partial dates using the post's publish date. Times are local (Europe/Vienna).
        If no start time is mentioned anywhere, use 20:00.
      - The same event often appears in several posts (e.g. monthly program and its own announcement).
        Return ONE entry per real-world event and merge the details from all posts mentioning it.
      - link: the URL of the post that announces the event most specifically.
      - name: a concise title; if the event has no name, use the main acts.
      - description: 1-2 sentences in German with notable details (lineup, genre, entry rules such as
        FLINTA*-only). Empty string if there is nothing to add.
      - location: "#{profile.location}" unless a post clearly states a different place.
      - category: the kind of event. Theater (plays, performance, improv), Konzerte (live music),
        Party (club nights, DJ sets), Kultur (exhibitions, film, readings, talks, markets),
        Workshop (participatory classes), Politik (demos, political talks), Andere (anything else).
      - Skip events that already happened, posts that are not event announcements (statements,
        lost & found, recaps), and events not open to the public.
    PROMPT
  end

  def self.post_blocks(post)
    blocks = [
      {
        type: "text",
        text: "Post #{post[:url]} — published #{post[:published_on].iso8601}\nCaption: #{post[:caption].presence || "(none)"}"
      }
    ]
    blocks << image_block(post[:image_url]) if post[:image_url].present?
    blocks.compact
  end

  # Instagram's CDN blocks Anthropic's URL fetcher via robots.txt,
  # so images are downloaded here and sent inline. A failed download
  # only drops the image; the caption is still extracted from.
  def self.image_block(image_url)
    response = HTTParty.get(image_url, headers: { "User-Agent" => USER_AGENT })
    return nil unless response.code == 200

    {
      type: "image",
      source: {
        type: "base64",
        media_type: response.headers["content-type"].presence || "image/jpeg",
        data: Base64.strict_encode64(response.body)
      }
    }
  end

  def self.anthropic
    @anthropic ||= Anthropic::Client.new
  end

  def self.pause(seconds) = sleep(seconds)

  private_class_method :fetch_posts, :extract_events, :system_prompt, :post_blocks, :image_block, :anthropic
end
