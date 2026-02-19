class FetchBrux
  def self.call
    response = HTTParty.get("https://brux.at/spielplan")
    document = Nokogiri::HTML(response.body)

    document.css('article[itemtype="https://schema.org/Event"]').each do |event_row|
      datetime = event_row.css('[itemprop="startDate"]').attr("content")&.then(&Time.zone.method(:parse))

      next unless datetime.present?

      name = event_row.css(".lp-title").text.strip
      link = event_row.css("a.lp-title-link").attr("href").value
      description = event_row.css(".lp-subtitle").text.strip
      location = "Brux"

      Event.create!(datetime:, location:, name:, link:, description:, organization: "Brux", source: :scraper)
    end
  end
end
