require "rails_helper"

RSpec.describe ReviewEvent do
  let(:event) do
    Event.create!(
      name: "Impro-Abend", location: "Bogen 30", organization: "Andere",
      datetime: 1.day.from_now, link: "https://example.com", source: :webform
    )
  end

  let(:messages) { double("messages") }

  before do
    client = double("Anthropic::Client", messages: messages)
    allow(Anthropic::Client).to receive(:new).and_return(client)
    ReviewEvent.instance_variable_set(:@anthropic, nil)
  end

  def stub_review(spam:, category:)
    text_block = double(type: :text, text: { spam:, category: }.to_json)
    allow(messages).to receive(:create).and_return(double(content: [ text_block ], stop_reason: :end_turn))
  end

  it "approves and categorizes legitimate submissions" do
    stub_review(spam: false, category: "Theater")

    ReviewEvent.call(event)

    expect(event.reload.approved_at).to be_present
    expect(event.category).to eq("Theater")
    expect(Event.published).to include(event)
  end

  it "categorizes spam but leaves it unapproved" do
    stub_review(spam: true, category: "Andere")

    ReviewEvent.call(event)

    expect(event.reload.approved_at).to be_nil
    expect(Event.published).not_to include(event)
    expect(Event.to_approve).to include(event)
  end

  it "sends the submission's fields to Claude" do
    stub_review(spam: false, category: "Kultur")

    ReviewEvent.call(event)

    expect(messages).to have_received(:create) do |params|
      submission = JSON.parse(params[:messages].first[:content])
      expect(submission).to include("name" => "Impro-Abend", "link" => "https://example.com")
    end
  end

  it "raises when Claude returns no text content" do
    allow(messages).to receive(:create).and_return(double(content: [], stop_reason: :refusal))

    expect { ReviewEvent.call(event) }.to raise_error(/no text content/)
    expect(event.reload.approved_at).to be_nil
  end
end
