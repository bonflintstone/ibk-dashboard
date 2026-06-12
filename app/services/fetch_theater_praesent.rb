class FetchTheaterPraesent
  # The Kupfticket shop page only lists a couple of highlighted events; the
  # full schedule lives in the Termine section of the theater's own website.
  def self.call
    response = HTTParty.get("https://www.theater-praesent.at/")
    document = Nokogiri::HTML(response.body)

    document.css(".thp-termine-row").map do |row|
      date = row.css(".thp-termine-date").text.match(/(\d{1,2})\.(\d{1,2})\./)
      time = row.css(".thp-termine-time").text.match(/(\d{1,2}):(\d{2})/)
      title = row.css(".thp-termine-title a").first
      next if date.nil? || title.nil?

      datetime = upcoming_datetime(day: date[1].to_i, month: date[2].to_i,
                                   hour: time ? time[1].to_i : 20, minute: time ? time[2].to_i : 0)
      next if datetime.nil?

      # The link text ends in a non-breaking-space-padded arrow.
      name = title.text.delete("➜").gsub("\u00A0", " ").strip

      Event.create(datetime:, location: "Theater Praesent", name:, link: title["href"],
                   description: "", organization: "Theater Praesent", source: :scraper)
    end
  end

  # The Termine list shows only upcoming events but its dates carry no year
  # ("Mi. 17.06."), so a date that already passed this year is next year's.
  def self.upcoming_datetime(day:, month:, hour:, minute:)
    date = Date.new(Date.current.year, month, day)
    date = date.next_year if date < Date.current
    Time.zone.local(date.year, date.month, date.day, hour, minute)
  rescue Date::Error
    nil
  end
end
