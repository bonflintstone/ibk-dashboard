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
  # Cap on images sent per post; carousel ("sidecar") posts can hold many, but
  # an event's details rarely span more than the first handful of slides.
  MAX_IMAGES_PER_POST = 10

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
    digest = posts_digest(posts)

    # Skip the (paid) extraction when the profile hasn't posted anything
    # new since the last successful run. Clear posts_digest to force one.
    # fetched_at drives RefetchAll's throttling and marks a successful
    # Instagram fetch — a raised error must leave it untouched.
    if digest == profile.posts_digest
      profile.update!(fetched_at: Time.current)
      return
    end

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

    profile.update!(posts_digest: digest, fetched_at: Time.current)
  end

  # Instagram regenerates every image URL with a fresh signed query string
  # (oe, _nc_oh, _nc_gid …) on each fetch, so digesting the raw posts would
  # change every run and defeat the skip. A post's content is fully captured
  # by its shortcode (post URL), publish date, caption and image count — an
  # image can't be swapped into an existing post — so the fingerprint is built
  # from those alone, ignoring the volatile URLs.
  def self.posts_digest(posts)
    fingerprint = posts.map do |post|
      [ post[:url], post[:published_on], post[:caption], post[:image_urls].size ]
    end
    Digest::SHA256.hexdigest(fingerprint.to_json)
  end

  def self.fetch_posts(username)
    response = nil
    MAX_ATTEMPTS.times do |attempt|
      response = Typhoeus.get(
        PROFILE_URL,
        params: { username: },
        headers: { "x-ig-app-id" => APP_ID, "User-Agent" => USER_AGENT },
        **proxy_options
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
        image_urls: image_urls(node)
      }
    end
  end

  # A carousel ("sidecar") post carries several images under
  # edge_sidecar_to_children; a single-photo post only has display_url.
  # Event flyers often span multiple slides (lineup, dates, prices), so all
  # of them are collected (capped by MAX_IMAGES_PER_POST).
  def self.image_urls(node)
    children = node.dig("edge_sidecar_to_children", "edges")
    urls =
      if children.present?
        children.filter_map { |child| child.dig("node", "display_url") }
      else
        [ node["display_url"] ]
      end
    urls.compact.first(MAX_IMAGES_PER_POST)
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

      You receive the venue's latest posts, each with its publish date, post URL, caption, and one or
      more images (often an event flyer or a monthly program; a carousel post may spread the lineup,
      dates and prices across several slides). Extract every upcoming public event (today or later).

      Rules:
      - Use both caption and images; flyers often contain details the caption omits, and a single post's
        slides may each announce a different event.
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
    # A post can carry several images (carousel); send each as its own block.
    blocks + post[:image_urls].filter_map { |image_url| image_block(image_url) }
  end

  # Instagram's CDN blocks Anthropic's URL fetcher via robots.txt,
  # so images are downloaded here and sent inline. A failed download
  # only drops the image; the caption is still extracted from.
  def self.image_block(image_url)
    response = Typhoeus.get(image_url, headers: { "User-Agent" => USER_AGENT }, **proxy_options)
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

  # Meta blocks Instagram requests on two independent layers: Ruby
  # net/http's TLS fingerprint is rejected at the edge (empty 429, any IP)
  # and datacenter IPs are walled off at the application layer (401).
  # Hence Typhoeus (libcurl's TLS handshake passes) through a residential
  # proxy when one is configured.
  def self.proxy_options
    return {} if ENV["DECODO_URL"].blank?

    { proxy: "http://#{ENV["DECODO_URL"]}", proxyuserpwd: ENV["DECODO_AUTH"] }
  end

  def self.anthropic
    @anthropic ||= Anthropic::Client.new
  end

  def self.pause(seconds) = sleep(seconds)

  private_class_method :posts_digest, :fetch_posts, :image_urls, :extract_events, :system_prompt,
                       :post_blocks, :image_block, :proxy_options, :anthropic
end
