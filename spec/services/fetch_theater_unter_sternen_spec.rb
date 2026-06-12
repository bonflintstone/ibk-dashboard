require "rails_helper"

RSpec.describe FetchTheaterUnterSternen do
  include ActiveSupport::Testing::TimeHelpers

  def item(date:, time:, title:, subtitle:, href:, status: "Geplant")
    <<~HTML
      <a href="#{href}" class="production-list__item">
        <div class="production-list__item__status production-list__item__status--scheduled">#{status}</div>
        <div class="production-list__item__content">
          <div class="production-list__item__left">
            <div class="production-list__item__datetime">
              <span class="production-list__item__datetime__date">#{date}</span>
              <span class="production-list__item__datetime__time">#{time}</span>
            </div>
            <span class="production-list__item__details">Details</span>
          </div>
          <div class="production-list__item__info">
            <span class="production-list__item__info__title">#{title}</span>
            <span class="production-list__item__info__subtitle">#{subtitle}</span>
          </div>
        </div>
      </a>
    HTML
  end

  let(:period) { "<p><em><strong>27.06. - 11.07.2026</strong></em>&nbsp;</p>" }

  let(:html) do
    <<~HTML
      <html><body>
        #{period}
        <section class="production-list">
          #{item(date: '27.06.', time: '19:30', title: 'Sindy Sinful: Ooops, I became a Queen',
                 subtitle: 'Eröffnung', href: '/events/32/36/sindy-sinful-ooops-i-became-a-queen')}
          #{item(date: '28.06.', time: '20:00', title: 'Der Bonsai',
                 subtitle: 'Westbahntheater', href: '/events/33/37/der-bonsai')}
          #{item(date: '10.06.', time: '20:00', title: 'Schon vorbei',
                 subtitle: 'Westbahntheater', href: '/events/1/1/schon-vorbei')}
          #{item(date: '29.06.', time: '20:00', title: 'Fällt aus',
                 subtitle: 'Westbahntheater', href: '/events/2/2/faellt-aus', status: 'Abgesagt')}
        </section>
      </body></html>
    HTML
  end

  before do
    travel_to Time.zone.local(2026, 6, 12, 12, 0)
    allow(HTTParty).to receive(:get).and_return(double(body: html))
  end

  after { travel_back }

  it "creates an event per production, resolving the year from the festival period" do
    FetchTheaterUnterSternen.call

    event = Event.find_by(name: "Der Bonsai")
    expect(event).to have_attributes(
      datetime: Time.zone.local(2026, 6, 28, 20, 0),
      location: "Zeughaus",
      link: "https://www.theateruntersternen.com/events/33/37/der-bonsai",
      description: "Westbahntheater",
      organization: "Theater unter Sternen",
      source: "scraper"
    )
  end

  it "skips past and cancelled events" do
    FetchTheaterUnterSternen.call

    expect(Event.pluck(:name)).to match_array([ "Sindy Sinful: Ooops, I became a Queen", "Der Bonsai" ])
  end

  context "when the page shows no festival period" do
    let(:period) { "" }

    it "raises instead of guessing the year" do
      expect { FetchTheaterUnterSternen.call }.to raise_error(/no festival period/)
    end
  end
end
