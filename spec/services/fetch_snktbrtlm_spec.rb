require "rails_helper"

RSpec.describe FetchSnktbrtlm do
  let(:html) do
    <<~HTML
      <html><body>
        <h2>Programm</h2>
        <h2>FREITAG, 12. Juni 2026 - SAMSTAG,13. Juni 2026</h2>
        <h2>zunder festival 2026</h2>
        <h2>SAMSTAG - 11.JULI 2026</h2>
        <h2>JOHANNA WAGNER
        BOXTURNIER</h2>
        <h2>DONNERSTAG, 24.9.2026 - SAMSTAG, 26.9.2026</h2>
        <h3>FÖHNFESTIVAL</h3>
        <h2>Archiv</h2>
        <h3>POSITIVE FUTURES FESTIVAL</h3>
        <h2>Hier findet ihr uns</h2>
      </body></html>
    HTML
  end

  before do
    allow(HTTParty).to receive(:get).and_return(double(body: html))
  end

  it "creates one event per date/title heading pair in the Programm section" do
    FetchSnktbrtlm.call

    expect(Event.where(organization: "SNKTBRTLM").pluck(:name)).to contain_exactly(
      "zunder festival 2026", "JOHANNA WAGNER BOXTURNIER", "FÖHNFESTIVAL"
    )
    expect(Event.find_by(name: "FÖHNFESTIVAL").datetime).to eq(Time.zone.local(2026, 9, 24, 20, 0))
    expect(Event.find_by(name: "zunder festival 2026")).to have_attributes(
      location: "St. Bartlmä",
      link: "https://www.snktbrtlm.com/#programm",
      source: "scraper"
    )
  end

  it "ignores the Archiv section" do
    FetchSnktbrtlm.call

    expect(Event.exists?(name: "POSITIVE FUTURES FESTIVAL")).to be(false)
  end

  it "raises when the Programm section is missing" do
    allow(HTTParty).to receive(:get).and_return(double(body: "<html><body></body></html>"))

    expect { FetchSnktbrtlm.call }.to raise_error(/Programm section/)
  end
end
