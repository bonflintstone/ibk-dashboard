class FetchKellertheater
  def self.call
    response = HTTParty.get("https://www.kellertheater.at/spielplan/terminuebersicht/")
    document = Nokogiri::HTML(response.body)

    document.css(".actdates .date").flat_map do |date_block|
      date = date_block.css(".day .long").text[%r{\d{2}\.\d{2}\.\d{4}}]
      next [] if date.blank?

      # A single day can list several shows; each is its own article.
      date_block.css(".dayacts article").filter_map do |article|
        # Some entries omit the start time ("um HH:MM") — default rather than
        # let a single odd row raise and abort the whole scrape.
        time = article.css("p.subtitle").text[/\d{1,2}:\d{2}/] || "20:00"
        datetime = Time.zone.strptime("#{date} #{time}", "%d.%m.%Y %H:%M")

        name = article.css("h4").text.strip
        description = article.css(".text p").text.strip
        link = article.css(".text a.more").attr("href")&.value || "https://www.kellertheater.at/spielplan/"

        Event.create(datetime:, location: "Kellertheater", name:, link:, description:, organization: "Kellertheater", source: :scraper)
      end
    end
  end
end
