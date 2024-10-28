class FetchTreibhaus
  def self.call
    response = HTTParty.get("https://treibhaus.at/programm")
    document = Nokogiri::HTML(response.body)

    document.css(".event-item").map do |event_row|
      datetime = event_row.css('[itemprop="startDate"]').attr("content").then(&Time.method(:parse))
      link = event_row.attr("data-details")
      name = event_row.css(".share-title").text.strip
      description = event_row.css(".share-sub").text.strip
      location = "Treibhaus"

      Event.create(datetime:, location:, name:, link:, description:, organization: "Treibhaus")
    end
  end
end
