require "rails_helper"

RSpec.describe FetchLeokinoOpenAir do
  include ActiveSupport::Testing::TimeHelpers

  def item(text, href:)
    %(<li><a href="#{href}"><span>#{text}</span></a></li>)
  end

  let(:heading) { "<h3>August 2026</h3>" }

  let(:html) do
    <<~HTML
      <html><body>
        <h1>Open<br>Air<br>Kino</h1>
        #{heading}
        <a href="https://www.leokino.at/film/teaser/">Jetzt im Kino</a>
        <ul>
          #{item("Sa. 01.08. Spaceballs", href: "https://www.leokino.at/film/spaceballs/")}
          #{item("Sa. 08.08. The Cradle <strong>*</strong>", href: "/film/the-cradle/")}
          #{item("Mo. 27.07. Schon vorbei", href: "https://www.leokino.at/film/schon-vorbei/")}
        </ul>
      </body></html>
    HTML
  end

  before do
    travel_to Time.zone.local(2026, 7, 30, 12, 0)
    allow(HTTParty).to receive(:get).and_return(double(body: html))
  end

  after { travel_back }

  it "creates an event per screening, resolving the year from the season heading" do
    FetchLeokinoOpenAir.call

    event = Event.find_by(name: "Spaceballs")
    expect(event).to have_attributes(
      datetime: Time.zone.local(2026, 8, 1, 21, 0),
      location: "Zeughaus",
      link: "https://www.leokino.at/film/spaceballs/",
      description: FetchLeokinoOpenAir::DESCRIPTION,
      organization: "Leokino Open Air",
      category: "Kultur",
      source: "scraper"
    )
  end

  it "mentions the free guided tour for starred screenings and resolves relative links" do
    FetchLeokinoOpenAir.call

    event = Event.find_by(name: "The Cradle")
    expect(event.description).to include("Führung")
    expect(event.link).to eq("https://www.leokino.at/film/the-cradle/")
  end

  it "skips past screenings and film links without a programme date" do
    FetchLeokinoOpenAir.call

    expect(Event.pluck(:name)).to match_array([ "Spaceballs", "The Cradle" ])
  end

  context "when the page shows no season year" do
    let(:heading) { "" }

    it "raises instead of guessing the year" do
      expect { FetchLeokinoOpenAir.call }.to raise_error(/no season year/)
    end
  end
end
