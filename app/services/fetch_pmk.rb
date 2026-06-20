class FetchPmk
  BASE_URL = "https://www.pmk.or.at"

  def self.call
    response = HTTParty.get("#{BASE_URL}/de/events")
    document = Nokogiri::HTML(response.body)

    document.css('div[class*="group/teaser"]').filter_map do |teaser|
      link_node = teaser.at_css('h2 a[href^="/de/events/"]')
      next if link_node.nil?

      name = link_node.text.strip
      next if name.blank?

      text = teaser.text.gsub(/\s+/, " ")
      date = text[%r{\d{1,2}\.\d{1,2}\.\d{4}}]
      next if date.nil?

      # Prefer the concert start; fall back to doors, then a sensible default.
      time = text[/Start:\s*(\d{1,2}:\d{2})/, 1] || text[/Doors:\s*(\d{1,2}:\d{2})/, 1] || "20:00"
      datetime = Time.zone.strptime("#{date} #{time}", "%d.%m.%Y %H:%M")

      description = teaser.css('div[class*="group/label"] span').map { |span| span.text.strip }.reject(&:blank?).join(", ")
      link = "#{BASE_URL}#{link_node["href"]}"

      Event.create(datetime:, location: "PMK", name:, link:, description:, organization: "PMK", source: :scraper)
    end
  end
end
