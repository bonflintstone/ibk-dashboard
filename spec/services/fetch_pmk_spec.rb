require "rails_helper"

RSpec.describe FetchPmk do
  def teaser(date:, name:, slug:, genres: [], doors: nil, start: nil)
    labels = genres.map do |genre|
      %(<div class="group/label inline-flex"><span class="text-xs">#{genre}</span></div>)
    end.join
    times = [ doors && "Doors: #{doors}", start && "Start: #{start}" ].compact.join(" ")

    <<~HTML
      <div class="group/teaser space-y-standard">
        <div>
          <p class="text-lg">#{date}</p>
          <h2 class="font-black"><a href="/de/events/#{slug}" class="hover:text-brand">#{name}</a></h2>
        </div>
        <div class="flex flex-wrap">#{labels}</div>
        <div class="group/meta">PMK #{times}</div>
      </div>
    HTML
  end

  let(:html) do
    <<~HTML
      <html><body>
        <div class="grid">
          #{teaser(date: "Sa. 20.6.2026", name: "ERPELISTICS | CIGOLLOS", slug: "erpelistics-cigollos",
                   genres: [ "Alternative-Rock", "Disco" ], doors: "19:30", start: "21:00")}
          #{teaser(date: "Do. 02.07.2026", name: "Prison Religion", slug: "prison-religion",
                   genres: [ "Rap", "Noise" ])}
          <div class="group/teaser"><a href="/de/events/archive">Archiv</a></div>
        </div>
      </body></html>
    HTML
  end

  before do
    allow(HTTParty).to receive(:get).and_return(double(body: html))
  end

  it "creates an event per teaser, linking to the absolute detail URL" do
    FetchPmk.call

    event = Event.find_by(name: "ERPELISTICS | CIGOLLOS")
    expect(event).to have_attributes(
      datetime: Time.zone.local(2026, 6, 20, 21, 0),
      location: "PMK",
      organization: "PMK",
      link: "https://www.pmk.or.at/de/events/erpelistics-cigollos",
      description: "Alternative-Rock, Disco",
      source: "scraper"
    )
  end

  it "prefers the start time but falls back to 20:00 when no time is given" do
    FetchPmk.call

    expect(Event.find_by(name: "Prison Religion").datetime).to eq(Time.zone.local(2026, 7, 2, 20, 0))
  end

  it "skips teasers without an event link, such as the archive button" do
    expect { FetchPmk.call }.to change(Event, :count).by(2)
  end
end
