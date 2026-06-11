# Gans Anders lists upcoming and past events as <article> cards whose
# fields are identified by their lucide icons (calendar, clock, map-pin).
# Past events are on the same page, so cards are filtered by date.
class FetchGansAnders
  URL = "https://www.gans-anders.com/en/events"

  def self.call
    response = HTTParty.get(URL)
    document = Nokogiri::HTML(response.body)

    document.css("article").each do |card|
      date_text = card.css("svg.lucide-calendar").first&.parent&.text
      next if date_text.nil?

      time = card.css("svg.lucide-clock").first&.parent&.text.to_s.match(/(\d{1,2}):(\d{2})/)
      hour, minute = time ? time.captures.map(&:to_i) : [ 20, 0 ]
      datetime = GermanDate.parse(date_text, hour:, minute:)
      next if datetime.nil? || datetime < Time.zone.now.beginning_of_day

      Event.create(
        name: card.css("h3").text.squish,
        datetime:,
        location: card.css("svg.lucide-map-pin").first&.parent&.text&.squish.presence || "Halle 5",
        description: card.css("p.line-clamp-2").text.squish.presence,
        link: card.ancestors("a").first&.[]("href").presence || URL,
        organization: "Gans Anders",
        source: :scraper
      )
    end
  end
end
