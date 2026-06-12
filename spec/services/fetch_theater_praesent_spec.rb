require "rails_helper"

RSpec.describe FetchTheaterPraesent do
  include ActiveSupport::Testing::TimeHelpers

  def row(date:, time:, name:, href:)
    <<~HTML
      <div class="thp-termine-row" data-filter-tags="theater">
        <div class="thp-termine-date-time-mobile">
          <div class="thp-termine-date">#{date}</div>
          <div class="thp-termine-time">#{time}</div>
        </div>
        <div class="thp-termine-titlewrap">
          <div class="thp-termine-title">
            <a href="#{href}">#{name}&nbsp;&nbsp;➜</a>
          </div>
          <div class="thp-ticket-button">
            <a class="thp-termine-ticket" href="https://kupfticket.com/events/whatever">Tickets</a>
          </div>
        </div>
      </div>
    HTML
  end

  let(:html) do
    <<~HTML
      <html><body><div class="thp-termine-list">
        #{row(date: 'Mi. 17.06.', time: '20:00 Uhr', name: 'LEOKINO&gt;replay: How to be Normal',
              href: 'https://www.theater-praesent.at/leokinoreplay-how-to-be-normal/')}
        #{row(date: 'Di. 05.01.', time: '19:30 Uhr', name: 'ctrl&#x2F;halten',
              href: 'https://www.theater-praesent.at/ctrlhalten/')}
        <div class="thp-termine-row">
          <div class="thp-termine-date">Do. 18.06.</div>
          <div class="thp-termine-time">20:00 Uhr</div>
        </div>
      </div></body></html>
    HTML
  end

  before do
    travel_to Time.zone.local(2026, 6, 12, 12, 0)
    allow(HTTParty).to receive(:get).and_return(double(body: html))
  end

  after { travel_back }

  it "creates an event per Termine row, linking to the theater's detail page" do
    FetchTheaterPraesent.call

    event = Event.find_by(name: "LEOKINO>replay: How to be Normal")
    expect(event).to have_attributes(
      datetime: Time.zone.local(2026, 6, 17, 20, 0),
      location: "Theater Praesent",
      link: "https://www.theater-praesent.at/leokinoreplay-how-to-be-normal/",
      organization: "Theater Praesent",
      source: "scraper"
    )
  end

  # The Termine list shows no year; dates that already passed this year
  # belong to the next one.
  it "rolls dates that lie behind the current date over to next year" do
    FetchTheaterPraesent.call

    expect(Event.find_by(name: "ctrl/halten").datetime).to eq(Time.zone.local(2027, 1, 5, 19, 30))
  end

  it "skips rows without a title link" do
    expect { FetchTheaterPraesent.call }.to change(Event, :count).by(2)
  end
end
