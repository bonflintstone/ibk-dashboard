require "rails_helper"

RSpec.describe FetchInstagram do
  let(:profile) do
    InstagramProfile.create!(
      username: "arche.ahoi", organization: "Arche Ahoi", location: "Bogen 30"
    )
  end

  let(:instagram_json) do
    {
      data: {
        user: {
          edge_owner_to_timeline_media: {
            edges: [
              {
                node: {
                  shortcode: "ABC123",
                  taken_at_timestamp: 2.days.ago.to_i,
                  display_url: "https://cdn.example.com/flyer.jpg",
                  edge_media_to_caption: { edges: [ { node: { text: "FREITAG 13.6. GROOVE HARBOR 23:00" } } ] }
                }
              },
              {
                node: {
                  shortcode: "DEF456",
                  taken_at_timestamp: 1.day.ago.to_i,
                  display_url: "https://cdn.example.com/program.jpg",
                  edge_media_to_caption: { edges: [] }
                }
              },
              {
                node: {
                  shortcode: "GHI789",
                  taken_at_timestamp: 1.day.ago.to_i,
                  display_url: "https://cdn.example.com/cover.jpg",
                  edge_media_to_caption: { edges: [ { node: { text: "Programm August" } } ] },
                  edge_sidecar_to_children: {
                    edges: [
                      { node: { display_url: "https://cdn.example.com/slide1.jpg" } },
                      { node: { display_url: "https://cdn.example.com/slide2.jpg" } },
                      { node: { display_url: "https://cdn.example.com/slide3.jpg" } }
                    ]
                  }
                }
              }
            ]
          }
        }
      }
    }.to_json
  end

  let(:extracted_events) do
    [
      {
        "name" => "Groove Harbor",
        "datetime" => 2.days.from_now.change(hour: 23).strftime("%Y-%m-%dT%H:%M"),
        "location" => "Bogen 30",
        "description" => "Clubnacht.",
        "link" => "https://www.instagram.com/p/ABC123/",
        "category" => "Party"
      },
      {
        "name" => "Vergangenes Event",
        "datetime" => 2.days.ago.change(hour: 23).strftime("%Y-%m-%dT%H:%M"),
        "location" => "Bogen 30",
        "description" => "",
        "link" => "https://www.instagram.com/p/DEF456/",
        "category" => "Konzerte"
      }
    ]
  end

  let(:messages) { double("messages") }

  before do
    allow(Typhoeus).to receive(:get)
      .with(FetchInstagram::PROFILE_URL, anything)
      .and_return(double(code: 200, body: instagram_json))
    allow(Typhoeus).to receive(:get)
      .with(%r{https://cdn\.example\.com/}, anything)
      .and_return(double(code: 200, body: "JPEGDATA", headers: { "content-type" => "image/jpeg" }))

    client = double("Anthropic::Client", messages: messages)
    allow(Anthropic::Client).to receive(:new).and_return(client)
    FetchInstagram.instance_variable_set(:@anthropic, nil)

    text_block = double(type: :text, text: { events: extracted_events }.to_json)
    allow(messages).to receive(:create).and_return(double(content: [ text_block ], stop_reason: :end_turn))
  end

  it "creates events from the extracted data" do
    FetchInstagram.call(profile)

    event = Event.find_by(name: "Groove Harbor")
    expect(event).to have_attributes(
      organization: "Arche Ahoi",
      location: "Bogen 30",
      description: "Clubnacht.",
      link: "https://www.instagram.com/p/ABC123/",
      category: "Party",
      source: "scraper"
    )
    expect(event.datetime).to eq(Time.zone.parse(extracted_events.first["datetime"]))
  end

  it "drops events in the past" do
    FetchInstagram.call(profile)

    expect(Event.exists?(name: "Vergangenes Event")).to be(false)
  end

  it "sends all posts with captions and images to Claude" do
    FetchInstagram.call(profile)

    expect(messages).to have_received(:create) do |params|
      blocks = params[:messages].first[:content]
      image_blocks = blocks.select { |block| block[:type] == "image" }
      # Two single-image posts plus the three slides of the carousel post.
      expect(image_blocks.size).to eq(5)
      expect(image_blocks.first[:source]).to include(type: "base64", media_type: "image/jpeg")
      expect(blocks.first[:text]).to include("https://www.instagram.com/p/ABC123/")
      expect(blocks.first[:text]).to include("GROOVE HARBOR")
    end
  end

  it "sends every slide of a multi-photo carousel post" do
    FetchInstagram.call(profile)

    expect(Typhoeus).to have_received(:get).with("https://cdn.example.com/slide1.jpg", anything)
    expect(Typhoeus).to have_received(:get).with("https://cdn.example.com/slide2.jpg", anything)
    expect(Typhoeus).to have_received(:get).with("https://cdn.example.com/slide3.jpg", anything)
    # The carousel's cover (display_url) is redundant with its slides, so it is skipped.
    expect(Typhoeus).not_to have_received(:get).with("https://cdn.example.com/cover.jpg", anything)
  end

  it "skips the extraction when the posts have not changed and events exist" do
    FetchInstagram.call(profile)
    FetchInstagram.call(profile.reload)

    expect(messages).to have_received(:create).once
  end

  it "stamps fetched_at on both extracting and digest-skipped runs" do
    FetchInstagram.call(profile)
    expect(profile.reload.fetched_at).to be_present

    profile.update!(fetched_at: 4.days.ago)
    FetchInstagram.call(profile)

    expect(profile.reload.fetched_at).to be > 1.minute.ago
  end

  it "skips extraction when only the signed image URLs rotate between fetches" do
    FetchInstagram.call(profile)

    # Instagram hands back the same posts but with freshly signed image URLs;
    # the content is unchanged, so no second (paid) extraction should run.
    rotated = instagram_json.gsub(".jpg", ".jpg?_nc_oh=ROTATED")
    allow(Typhoeus).to receive(:get)
      .with(FetchInstagram::PROFILE_URL, anything)
      .and_return(double(code: 200, body: rotated))

    FetchInstagram.call(profile.reload)

    expect(messages).to have_received(:create).once
  end

  it "re-extracts after the digest is cleared" do
    FetchInstagram.call(profile)
    Event.where(organization: profile.organization).destroy_all
    profile.reload.update!(posts_digest: nil)

    FetchInstagram.call(profile)

    expect(messages).to have_received(:create).twice
    expect(Event.exists?(name: "Groove Harbor")).to be(true)
  end

  it "keeps old events and stores the digest when no upcoming events are extracted" do
    old_event = Event.create!(
      name: "Altes Event", location: "Bogen 30", organization: profile.organization,
      datetime: 1.day.from_now, link: "https://example.com", source: :scraper
    )
    allow(messages).to receive(:create)
      .and_return(double(content: [ double(type: :text, text: { events: [] }.to_json) ], stop_reason: :end_turn))

    FetchInstagram.call(profile)

    expect(Event.exists?(old_event.id)).to be(true)
    expect(profile.reload.posts_digest).to be_present
  end

  it "routes Instagram requests through the residential proxy when configured" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("DECODO_URL").and_return("gate.example.com:7000")
    allow(ENV).to receive(:[]).with("DECODO_AUTH").and_return("user:pass")

    FetchInstagram.call(profile)

    proxy = { proxy: "http://gate.example.com:7000", proxyuserpwd: "user:pass" }
    expect(Typhoeus).to have_received(:get).with(FetchInstagram::PROFILE_URL, hash_including(proxy))
    expect(Typhoeus).to have_received(:get).with(%r{https://cdn\.example\.com/}, hash_including(proxy)).exactly(5).times
  end

  it "raises when Instagram does not respond with 200" do
    allow(Typhoeus).to receive(:get).and_return(double(code: 403, body: ""))

    expect { FetchInstagram.call(profile) }.to raise_error(/403/)
  end

  it "retries with backoff when Instagram rate-limits" do
    allow(FetchInstagram).to receive(:pause)
    rate_limited = double(code: 429, body: "", headers: { "retry-after" => "10" })
    allow(Typhoeus).to receive(:get)
      .with(FetchInstagram::PROFILE_URL, anything)
      .and_return(rate_limited, rate_limited, double(code: 200, body: instagram_json))

    FetchInstagram.call(profile)

    expect(FetchInstagram).to have_received(:pause).with(10).ordered
    expect(FetchInstagram).to have_received(:pause).with(20).ordered
    expect(Event.exists?(name: "Groove Harbor")).to be(true)
  end

  it "gives up after repeated rate limiting" do
    allow(FetchInstagram).to receive(:pause)
    rate_limited = double(code: 429, body: "", headers: {})
    allow(Typhoeus).to receive(:get)
      .with(FetchInstagram::PROFILE_URL, anything)
      .and_return(rate_limited)

    expect { FetchInstagram.call(profile) }.to raise_error(/429/)
    expect(FetchInstagram).to have_received(:pause).twice
  end
end
