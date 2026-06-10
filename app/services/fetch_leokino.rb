class FetchLeokino
  BASE_URL = "https://www.leokino.at"

  # The program is loaded via AJAX fragments, one day per request.
  # Film synopses only exist on the film detail pages, fetched once per film.
  def self.call
    synopses = {}

    (Date.today..Date.today + 6).each do |date|
      response = HTTParty.get("#{BASE_URL}/ajax/programm.php", query: { dateSet: date.to_s })
      document = Nokogiri::HTML(response.body)

      document.css(".colpadding1").each do |screening|
        date_text = screening.css("h6.left").text[/\d\d\.\d\d\.\d{4}/]
        time = screening.css("h6.right").text.strip.sub(".", ":")
        title_link = screening.css("h4.filmtitel a").first
        next if date_text.blank? || time.blank? || title_link.blank?

        datetime = Time.zone.parse("#{Date.parse(date_text).iso8601} #{time}")
        name = title_link.text.strip
        link = URI.join(BASE_URL, title_link["href"]).to_s

        # Bare text nodes inside the bottom h6: hall, "R: director", version (OmU/OV)
        details = screening.css(".programmBottom h6").first
          &.children&.select(&:text?)&.map { |node| node.text.strip }&.compact_blank || []
        location = details.first.presence || "Leokino"
        description = synopses[link] ||= fetch_synopsis(link, fallback: details.drop(1).join(", "))

        Event.create(datetime:, location:, name:, link:, description:, organization: "Leokino", source: :scraper)
      end
    end
  end

  def self.fetch_synopsis(link, fallback:)
    response = HTTParty.get(link)
    document = Nokogiri::HTML(response.body)

    synopsis = document.css(".col9 .col6 > div")
      .map { |node| node.text.gsub(/\s+/, " ").strip }
      .find { |text| text.length > 100 }

    synopsis.presence || fallback
  rescue StandardError
    fallback
  end
end
