# The SNKTBRTLM homepage lists the program as alternating headings:
# a date heading ("SAMSTAG - 11.JULI 2026") followed by the event title,
# between the "Programm" and "Archiv" sections. No times are published,
# so events default to 20:00.
class FetchSnktbrtlm
  URL = "https://www.snktbrtlm.com/"

  def self.call
    response = HTTParty.get(URL)
    headings = Nokogiri::HTML(response.body).css("h1, h2, h3").to_a

    programm = headings.index { |heading| heading.text.strip == "Programm" }
    archiv = headings.index { |heading| heading.text.strip == "Archiv" }
    raise "Programm section not found" if programm.nil? || archiv.nil?

    pending_date = nil
    headings[(programm + 1)...archiv].each do |heading|
      text = heading.text.squish

      if (date = GermanDate.parse(text))
        pending_date = date
      elsif pending_date
        Event.create(
          name: text, datetime: pending_date, location: "St. Bartlmä",
          link: "#{URL}#programm", organization: "SNKTBRTLM", source: :scraper
        )
        pending_date = nil
      end
    end
  end
end
