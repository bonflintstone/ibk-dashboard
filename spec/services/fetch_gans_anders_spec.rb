require "rails_helper"

RSpec.describe FetchGansAnders do
  include ActiveSupport::Testing::TimeHelpers

  def card(date:, time:, name:, location:, description:, href: nil)
    article = <<~HTML
      <article>
        <span><svg class="lucide lucide-calendar"></svg>#{date}</span>
        <span><svg class="lucide lucide-clock"></svg>#{time}</span>
        <h3>#{name}</h3>
        <p><svg class="lucide lucide-map-pin"></svg>#{location}</p>
        <p class="text-sm line-clamp-2">#{description}</p>
      </article>
    HTML
    href ? "<a href=\"#{href}\">#{article}</a>" : article
  end

  let(:html) do
    <<~HTML
      <html><body>
        #{card(date: 'Fr., 3. Juli 2026', time: '14:00 – 23:59', name: 'GABONSA Festival 2026',
               location: 'Old Golf Area, Österreich', description: 'Musik, Installation und Performance.',
               href: 'https://gabonsa.com/')}
        #{card(date: 'Di., 16. Apr. 2024', time: '22:00', name: 'Tante Emma',
               location: 'Halle 5, Innsbruck', description: 'Club Night in der Halle 5.')}
      </body></html>
    HTML
  end

  before do
    travel_to Time.zone.local(2026, 6, 11, 12, 0)
    allow(HTTParty).to receive(:get).and_return(double(body: html))
  end

  after { travel_back }

  it "creates upcoming events with date, time, location, description and link" do
    FetchGansAnders.call

    event = Event.find_by(name: "GABONSA Festival 2026")
    expect(event).to have_attributes(
      datetime: Time.zone.local(2026, 7, 3, 14, 0),
      location: "Old Golf Area, Österreich",
      description: "Musik, Installation und Performance.",
      link: "https://gabonsa.com/",
      organization: "Gans Anders",
      source: "scraper"
    )
  end

  it "skips past events" do
    FetchGansAnders.call

    expect(Event.exists?(name: "Tante Emma")).to be(false)
  end
end
