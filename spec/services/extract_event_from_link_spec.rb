require "rails_helper"

RSpec.describe ExtractEventFromLink do
  let(:messages) { double("messages") }
  let(:html) { "<html><head><title>Treibhaus</title></head><body><script>ignore()</script><h1>Großes Konzert</h1></body></html>" }

  before do
    client = double("Anthropic::Client", messages: messages)
    allow(Anthropic::Client).to receive(:new).and_return(client)
    ExtractEventFromLink.instance_variable_set(:@anthropic, nil)
    allow(HTTParty).to receive(:get).and_return(double(code: 200, body: html))
  end

  def stub_extraction(fields)
    text_block = double(type: :text, text: fields.to_json)
    allow(messages).to receive(:create).and_return(double(content: [ text_block ], stop_reason: :end_turn))
  end

  it "returns the extracted fields" do
    stub_extraction(name: "Großes Konzert", location: "Treibhaus", datetime: "2026-06-20T20:00", description: "Cool.")

    expect(ExtractEventFromLink.call("treibhaus.at/programm")).to eq(
      "name" => "Großes Konzert", "location" => "Treibhaus",
      "datetime" => "2026-06-20T20:00", "description" => "Cool."
    )
  end

  it "adds a scheme to bare URLs and sends the page text to Claude" do
    stub_extraction(name: "", location: "", datetime: "", description: "")

    ExtractEventFromLink.call("treibhaus.at/programm")

    expect(HTTParty).to have_received(:get).with("https://treibhaus.at/programm", anything)
    expect(messages).to have_received(:create) do |params|
      content = params[:messages].first[:content]
      expect(content).to include("Großes Konzert")
      expect(content).not_to include("ignore()") # script stripped
    end
  end

  it "raises when the page cannot be loaded" do
    allow(HTTParty).to receive(:get).and_return(double(code: 404, body: ""))

    expect { ExtractEventFromLink.call("https://example.test/x") }.to raise_error(/Could not load/)
  end

  it "rejects non-http URLs" do
    expect { ExtractEventFromLink.call("javascript:alert(1)") }.to raise_error(/Unsupported URL/)
  end
end
