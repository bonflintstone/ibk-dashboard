class FetchKellertheater
  def self.call
    response = HTTParty.get("https://www.kellertheater.at/spielplan/terminuebersicht/")
    document = Nokogiri::HTML(response.body)

    document.css(".actdates .date").map do |event_row|
      datestring = event_row.css(".day .short").text
      timestring = event_row.css("p.subtitle").text.split(" um ").last.strip

      datetime = Time.zone.strptime(datestring.split.last + timestring, '%d.%m.%y %H:%M')
      next unless datetime.present?

      name = event_row.css("article h4").text.strip
      description = event_row.css(".text p").text
      location = "Kellertheater"
      link = event_row.css(".text a.more").attr("href").value

      Event.create(datetime:, location:, name:, link:, description:, organization: "Kellertheater", source: :scraper)
    end
  end
end
