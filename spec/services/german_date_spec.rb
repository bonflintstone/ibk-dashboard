require "rails_helper"

RSpec.describe GermanDate do
  it "parses numeric dates" do
    expect(GermanDate.parse("DONNERSTAG, 24.9.2026")).to eq(Time.zone.local(2026, 9, 24, 20, 0))
  end

  it "parses month names with flexible casing and spacing" do
    expect(GermanDate.parse("SAMSTAG - 11.JULI 2026")).to eq(Time.zone.local(2026, 7, 11, 20, 0))
    expect(GermanDate.parse("Fr., 3. Juli 2026")).to eq(Time.zone.local(2026, 7, 3, 20, 0))
    expect(GermanDate.parse("Sa., 18. Jän. 2026")).to eq(Time.zone.local(2026, 1, 18, 20, 0))
    expect(GermanDate.parse("22. März 2026")).to eq(Time.zone.local(2026, 3, 22, 20, 0))
  end

  it "takes the first date of a range" do
    expect(GermanDate.parse("FREITAG, 12. Juni 2026 - SAMSTAG,13. Juni 2026"))
      .to eq(Time.zone.local(2026, 6, 12, 20, 0))
  end

  it "accepts a custom time" do
    expect(GermanDate.parse("3. Juli 2026", hour: 14, minute: 30)).to eq(Time.zone.local(2026, 7, 3, 14, 30))
  end

  it "returns nil for text without a date or with an unknown month" do
    expect(GermanDate.parse("FÖHNFESTIVAL")).to be_nil
    expect(GermanDate.parse("3. Frimaire 2026")).to be_nil
  end
end
