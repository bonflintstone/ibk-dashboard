require "rails_helper"

RSpec.describe FetchKellertheater do
  def article(name:, subtitle:, href: "https://www.kellertheater.at/spielplan/#{name.parameterize}/", description: "Worum es geht.")
    <<~HTML
      <article>
        <h4>#{name}</h4>
        <p class="subtitle">#{subtitle}</p>
        <div class="details">
          <a href="#{href}"><picture><img src="poster.jpg"></picture></a>
          <div class="text">
            <p>#{description}</p>
            <a class="submit more" href="#{href}">mehr erfahren</a>
            <a class="submit calendar" href="#{href}reservierung/">Karten-Reservierung</a>
          </div>
        </div>
      </article>
    HTML
  end

  def date_block(long:, short:, articles:)
    <<~HTML
      <div class="bg_1 date">
        <div class="day">
          <span class="long">#{long}</span>
          <span class="short">#{short}</span>
        </div>
        <div class="dayacts">#{articles}</div>
      </div>
    HTML
  end

  let(:html) do
    <<~HTML
      <html><body>
        <section class="actdates">
          <div class="container">
            <h3>Juni 2026</h3>
            #{date_block(long: 'Samstag, 20.06.2026', short: 'Sa, 20.06.26',
                         articles: article(name: 'Ausgerechnet Marlene!', subtitle: 'von Anne Clausen  um 20:00&nbsp;Uhr'))}
            #{date_block(long: 'Sonntag, 21.06.2026', short: 'So, 21.06.26',
                         articles: article(name: 'Matinee', subtitle: 'um 11:00&nbsp;Uhr') +
                                   article(name: 'Abendvorstellung', subtitle: 'um 19:30&nbsp;Uhr'))}
            #{date_block(long: 'Montag, 22.06.2026', short: 'Mo, 22.06.26',
                         articles: article(name: 'Lesung ohne Zeit', subtitle: 'Eintritt frei'))}
          </div>
        </section>
      </body></html>
    HTML
  end

  before do
    allow(HTTParty).to receive(:get).and_return(double(body: html))
  end

  it "creates an event with the parsed date, time and detail link" do
    FetchKellertheater.call

    event = Event.find_by(name: "Ausgerechnet Marlene!")
    expect(event).to have_attributes(
      datetime: Time.zone.local(2026, 6, 20, 20, 0),
      location: "Kellertheater",
      organization: "Kellertheater",
      link: "https://www.kellertheater.at/spielplan/ausgerechnet-marlene/",
      description: "Worum es geht.",
      source: "scraper"
    )
  end

  it "creates a separate event for each show on a day with several articles" do
    FetchKellertheater.call

    expect(Event.find_by(name: "Matinee").datetime).to eq(Time.zone.local(2026, 6, 21, 11, 0))
    expect(Event.find_by(name: "Abendvorstellung").datetime).to eq(Time.zone.local(2026, 6, 21, 19, 30))
  end

  it "falls back to 20:00 when an entry states no start time" do
    FetchKellertheater.call

    expect(Event.find_by(name: "Lesung ohne Zeit").datetime).to eq(Time.zone.local(2026, 6, 22, 20, 0))
  end
end
