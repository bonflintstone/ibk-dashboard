class FetchLeokino
  def self.call
    response = HTTParty.get("https://leokino.at")
    document = Nokogiri::HTML(response.body)

    document.css("table table td:first-child table tr").map do |movie_row|
      date = movie_row.css("td:first-child > span").text.strip
      next unless date.present?

      time = movie_row.css("td:first-child h3:first-of-type").text.strip.sub(".", ":")
      datetime = Time.parse("#{date} #{time}")

      location = movie_row.css("td:first-child h3:last-of-type").text.strip
      name = movie_row.css("td:last-child h3 a").children.map(&:text).join(" ")
      link = "https://leokino.at" + movie_row.css("td:last-child h3 a").attr("href").value
      description = movie_row.css("td:last-child p:last-child").text.strip

      Event.create(datetime:, location:, name:, link:, description:, organization: "Leokino")
    end
  end
end
