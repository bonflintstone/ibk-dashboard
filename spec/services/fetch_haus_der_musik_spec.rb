require "rails_helper"

RSpec.describe FetchHausDerMusik do
  def article(datetime:, name:, slug:, place:, organizer:)
    <<~HTML
      <article>
        <time datetime="#{datetime}"></time>
        <h2 class="title-5">#{name}</h2>
        <div class="info"><span>Beschreibung von #{name}</span> <a href="/kalender/#{slug}/">Details</a></div>
        <div class="stats">
          <div class="stat"><div>Beginn</div><strong>19.30</strong></div>
          <div class="stat"><div>Ort</div><strong>#{place}</strong></div>
          <div class="stat"><div>Veranstalter</div><strong>#{organizer}</strong></div>
        </div>
      </article>
    HTML
  end

  let(:html) do
    <<~HTML
      <html><body><div class="EventList">
        #{article(datetime: 1.day.from_now.change(hour: 19, min: 30).iso8601, name: "Festkonzert",
                  slug: "festkonzert", place: "Großer Saal", organizer: "Lions Club Innsbruck")}
        #{article(datetime: 2.days.from_now.change(hour: 20).iso8601, name: "Maria Stuart",
                  slug: "maria-stuart", place: "Kammerspiele", organizer: "Tiroler Landestheater")}
      </div></body></html>
    HTML
  end

  before { allow(HTTParty).to receive(:get).and_return(double(body: html)) }

  it "imports events by other organizers" do
    FetchHausDerMusik.call

    event = Event.find_by!(name: "Festkonzert")
    expect(event).to have_attributes(
      organization: "Haus der Musik",
      location: "Großer Saal",
      link: "https://www.haus-der-musik-innsbruck.at/kalender/festkonzert/"
    )
  end

  it "skips Landestheater shows, which FetchTirolerLandestheater already imports" do
    FetchHausDerMusik.call

    expect(Event.where(name: "Maria Stuart")).to be_empty
  end
end
