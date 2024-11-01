class FetchTheaterPraesent
  def self.call
    response = HTTParty.get("https://kupfticket.com/shops/theater-praesent")
    document = Nokogiri::HTML(response.body)

    # we get some json stuff here. No idea whats going on but I guess it works well enough
    JSON.parse(document.css("body").text).dig("props", "pageProps", "events", "edges").map do |event_row|
      title = event_row.dig("node", "title")
      datetime = event_row.dig("node", "date", "start")&.then(&Time.method(:parse))
      description = ""
      link = "https://kupfticket.com/shops/theater-praesent"

      Event.create(datetime:, location: "Theater Praesent", name: title, link:, description:, organization: "Theater Praesent", source: :scraper)
    end
  end
end
