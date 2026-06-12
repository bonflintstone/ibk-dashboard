require "rails_helper"

RSpec.describe FetchMontagu do
  include ActiveSupport::Testing::TimeHelpers

  let(:html) do
    <<~HTML
      <html><body><main><div class="content">
        <figure class="wp-block-image size-large">
          <img src="/wp-content/uploads/2026/06/June-26-print-410x1024.jpg"
               srcset="/wp-content/uploads/2026/06/June-26-print-410x1024.jpg 410w,
                       /wp-content/uploads/2026/06/June-26-print-120x300.jpg 120w,
                       /wp-content/uploads/2026/06/June-26-print.jpg 900w"
               alt="Montagu Hostel June 2026 programme">
        </figure>
      </div></main></body></html>
    HTML
  end

  let(:extracted_events) do
    [
      {
        "name" => "Open Mic Night",
        "datetime" => "2026-06-20T21:00",
        "description" => "Offene Bühne für alle.",
        "category" => "Konzerte"
      },
      {
        "name" => "Vergangenes Event",
        "datetime" => "2026-06-05T20:00",
        "description" => "",
        "category" => "Party"
      }
    ]
  end

  let(:messages) { double("messages") }

  before do
    travel_to Time.zone.local(2026, 6, 12, 12, 0)

    allow(HTTParty).to receive(:get).with(FetchMontagu::URL)
      .and_return(double(body: html))
    allow(HTTParty).to receive(:get)
      .with("https://www.montagu-hostel.com/wp-content/uploads/2026/06/June-26-print.jpg")
      .and_return(double(body: "JPEGDATA", headers: { "content-type" => "image/jpeg" }))

    client = double("Anthropic::Client", messages: messages)
    allow(Anthropic::Client).to receive(:new).and_return(client)
    FetchMontagu.instance_variable_set(:@anthropic, nil)

    text_block = double(type: :text, text: { events: extracted_events }.to_json)
    allow(messages).to receive(:create).and_return(double(content: [ text_block ], stop_reason: :end_turn))
  end

  after { travel_back }

  it "creates events from the extracted poster data" do
    FetchMontagu.call

    event = Event.find_by(name: "Open Mic Night")
    expect(event).to have_attributes(
      datetime: Time.zone.local(2026, 6, 20, 21, 0),
      location: "Montagu Bar",
      description: "Offene Bühne für alle.",
      link: FetchMontagu::URL,
      organization: "Montagu",
      category: "Konzerte",
      source: "scraper"
    )
  end

  it "drops events in the past" do
    FetchMontagu.call

    expect(Event.exists?(name: "Vergangenes Event")).to be(false)
  end

  it "sends the full-size poster image to Claude" do
    FetchMontagu.call

    expect(messages).to have_received(:create) do |params|
      image = params[:messages].first[:content].first
      expect(image[:type]).to eq("image")
      expect(image[:source]).to eq(
        type: "base64", media_type: "image/jpeg", data: Base64.strict_encode64("JPEGDATA")
      )
    end
  end

  it "sends all posters when current and next month are both up" do
    html.sub!("</figure>", <<~HTML)
      </figure>
      <figure class="wp-block-image size-large">
        <img src="/wp-content/uploads/2026/06/July-26-print.jpg"
             alt="Montagu Hostel July 2026 programme">
      </figure>
    HTML
    allow(HTTParty).to receive(:get)
      .with("https://www.montagu-hostel.com/wp-content/uploads/2026/06/July-26-print.jpg")
      .and_return(double(body: "JULYDATA", headers: { "content-type" => "image/jpeg" }))

    FetchMontagu.call

    expect(messages).to have_received(:create) do |params|
      images = params[:messages].first[:content]
      expect(images.size).to eq(2)
      expect(images.last[:source][:data]).to eq(Base64.strict_encode64("JULYDATA"))
    end
  end

  it "falls back to the img src when there is no srcset" do
    html.gsub!(/srcset="[^"]*"/, "")
    allow(HTTParty).to receive(:get)
      .with("https://www.montagu-hostel.com/wp-content/uploads/2026/06/June-26-print-410x1024.jpg")
      .and_return(double(body: "JPEGDATA", headers: { "content-type" => "image/jpeg" }))

    FetchMontagu.call

    expect(Event.exists?(name: "Open Mic Night")).to be(true)
  end

  it "raises when the page contains no poster" do
    allow(HTTParty).to receive(:get).with(FetchMontagu::URL)
      .and_return(double(body: "<html><body><div class='content'></div></body></html>"))

    expect { FetchMontagu.call }.to raise_error(/no programme poster/)
  end
end
