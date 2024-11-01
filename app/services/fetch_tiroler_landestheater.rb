class FetchTirolerLandestheater
  def self.call
    response = HTTParty.get("https://www.landestheater.at/kalender/?spielzeit=aktuell")
    document = Nokogiri::HTML(response.body)

    # document.css('time').each { puts _1.attr('datetime') }

    document.css("#listitems").children.each do |event_rows_by_date|
      date = event_rows_by_date.css("a").attr("data-date")&.value&.then(&Date.method(:parse))

      next if date.blank? || date < Date.today || date > 2.month.from_now

      event_rows_by_date.css("> a").each do |event_row|
        # puts event_row.text.gsub(/\s+/, ' ').strip

        time = event_row.css(".info").text[/(\d\d\.\d\d)/]&.sub(".", ":")

        next if time.blank?

        datetime = Time.parse("#{date} #{time}", "%d.%m.%Y %H.%M")
        name = event_row.css("h4").text
        link = event_row.attr("href")
        location = event_row.css(".info > span:first-child").text
        description = event_row.css("h4 + span").text

        Event.create(datetime:, name:, link:, location:, description:, organization: "Tiroler Landestheater", source: :scraper)
      end
    end
  end
end
