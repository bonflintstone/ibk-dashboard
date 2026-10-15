class FetchHausDerMusik
  # The Landestheater plays the Kammerspiele, [K2] and Kleiner Saal here, and
  # those shows are already scraped (with more detail) by FetchTirolerLandestheater.
  SKIPPED_ORGANIZERS = [ "Tiroler Landestheater" ].freeze

  def self.call
    response = HTTParty.get("https://www.haus-der-musik-innsbruck.at/kalender/")
    document = Nokogiri::HTML(response.body)

    document.css(".EventList article").map do |event_row|
      datetime = event_row.css("time").attr("datetime")&.then(&Time.zone.method(:parse))
      next unless datetime.present?
      next if SKIPPED_ORGANIZERS.include?(organizer(event_row))

      name = event_row.css("h2.title-5").text.strip
      description = event_row.css(".info span:first-child").text
      location = event_row.css(".stats .stat:nth-child(2) strong").text
      link = "https://www.haus-der-musik-innsbruck.at" + event_row.css(".info a").attr("href").value

      Event.create(datetime:, location:, name:, link:, description:, organization: "Haus der Musik", source: :scraper)
    end
  end

  # The "Veranstalter" stat, e.g. "Tiroler Landestheater" or "Lions Club Innsbruck".
  def self.organizer(event_row)
    stat = event_row.css(".stats .stat").find { |node| node.text.strip.start_with?("Veranstalter") }
    stat&.css("strong")&.text&.strip
  end

  private_class_method :organizer
end
