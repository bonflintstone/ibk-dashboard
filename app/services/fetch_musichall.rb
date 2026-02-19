class FetchMusichall
  def self.call
    response = HTTParty.get("https://music-hall.at/veranstaltungen/aktuelleveranstaltungen.html")
    document = Nokogiri::HTML(response.body)

    document.css(".mod-dpcalendar-upcoming-panel__events .dp-event").map do |event_row|
      datetime = event_row.css(".dp-date.dp-time").text&.then { Time.zone.parse(_1) }

      next unless datetime.present?

      name = event_row.css(".dp-event-url.dp-link").text.strip
      description = ""
      location = "Innsbruck Music Hall"
      link = event_row.css(".dp-event-url.dp-link").attr("href").value

      Event.create(datetime:, location:, name:, link:, description:, organization: "Innsbruck Music Hall", source: :scraper)
    end
  end
end
