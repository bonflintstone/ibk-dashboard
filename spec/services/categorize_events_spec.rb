require "rails_helper"

RSpec.describe CategorizeEvents do
  def create_event(name, organization: "Treibhaus", category: nil)
    Event.create!(
      name:, location: organization, organization:, category:,
      datetime: 1.day.from_now, link: "https://example.com", source: :scraper
    )
  end

  let(:messages) { double("messages") }

  before do
    client = double("Anthropic::Client", messages: messages)
    allow(Anthropic::Client).to receive(:new).and_return(client)
    CategorizeEvents.instance_variable_set(:@anthropic, nil)
  end

  def stub_response(categories)
    text_block = double(type: :text, text: { categories: }.to_json)
    allow(messages).to receive(:create).and_return(double(content: [ text_block ], stop_reason: :end_turn))
  end

  it "assigns the categories returned by Claude" do
    concert = create_event("Jazzkonzert")
    rave = create_event("Technonacht")
    stub_response([
      { id: concert.id, category: "Konzerte" },
      { id: rave.id, category: "Party" }
    ])

    CategorizeEvents.call

    expect(concert.reload.category).to eq("Konzerte")
    expect(rave.reload.category).to eq("Party")
  end

  it "sends only uncategorized events" do
    create_event("Schon kategorisiert", category: "Theater")
    pending_event = create_event("Neu")
    stub_response([ { id: pending_event.id, category: "Kultur" } ])

    CategorizeEvents.call

    expect(messages).to have_received(:create) do |params|
      ids = JSON.parse(params[:messages].first[:content]).map { |event| event["id"] }
      expect(ids).to eq([ pending_event.id ])
    end
  end

  it "does not call Claude when there is nothing to categorize" do
    create_event("Schon kategorisiert", category: "Theater")

    CategorizeEvents.call

    expect(messages).not_to have_received(:create) if messages.respond_to?(:create)
  end

  it "leaves events the model skipped uncategorized" do
    answered = create_event("Beantwortet")
    skipped = create_event("Vergessen")
    stub_response([ { id: answered.id, category: "Workshop" } ])

    CategorizeEvents.call

    expect(answered.reload.category).to eq("Workshop")
    expect(skipped.reload.category).to be_nil
  end

  it "ignores ids that do not belong to the batch" do
    event = create_event("Echt")
    stub_response([
      { id: event.id, category: "Politik" },
      { id: 999_999, category: "Party" }
    ])

    expect { CategorizeEvents.call }.not_to raise_error
    expect(event.reload.category).to eq("Politik")
  end

  it "raises when Claude returns no text content" do
    create_event("Event")
    allow(messages).to receive(:create).and_return(double(content: [], stop_reason: :refusal))

    expect { CategorizeEvents.call }.to raise_error(/no text content/)
  end
end
