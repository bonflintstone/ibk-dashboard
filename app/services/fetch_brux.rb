class FetchBrux
  def self.call
    response = HTTParty.get("https://brux.at/spielplan")
    document = Nokogiri::HTML(response.body)

    document.css("article[data-spielstaette]").each do |event_row|
      datetime = event_row.css('[itemprop="startDate"]').attr("content")&.then(&Time.method(:parse))

      next unless datetime.present?

      name = event_row.css("a.c-link").text.strip
      link = "https://www.brux.at/" + event_row.css("a.c-link").attr("href").value
      description = event_row.css("p").text.strip
      location = "Brux"

      Event.create(datetime:, location:, name:, link:, description:, organization: "Brux")
    end
  end
end
