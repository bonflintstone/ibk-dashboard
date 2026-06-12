# Theater unter Sternen is a two-week summer theater festival in the
# Zeughaus; its homepage lists the whole programme of the current season.
class FetchTheaterUnterSternen
  URL = "https://www.theateruntersternen.com/"

  def self.call
    document = Nokogiri::HTML(HTTParty.get(URL).body)
    year = festival_year(document)

    document.css(".production-list__item").map do |item|
      # The status badge currently only shows "Geplant"; don't import
      # shows the festival has called off.
      next if item.css(".production-list__item__status").text.match?(/abgesagt/i)

      date = item.css(".production-list__item__datetime__date").text.match(/(\d{1,2})\.(\d{1,2})\./)
      time = item.css(".production-list__item__datetime__time").text.match(/(\d{1,2}):(\d{2})/)
      # squish, not strip: some titles end in a non-breaking space.
      name = item.css(".production-list__item__info__title").text.squish
      next if date.nil? || name.blank?

      datetime = Time.zone.local(year, date[2].to_i, date[1].to_i,
                                 time ? time[1].to_i : 20, time ? time[2].to_i : 0)
      # The programme stays online after the festival; outside the season
      # every date is past and the scrape legitimately yields no events.
      next if datetime < Time.zone.now.beginning_of_day

      Event.create(datetime:, name:, location: "Zeughaus",
                   link: URI.join(URL, item["href"]).to_s,
                   description: item.css(".production-list__item__info__subtitle").text.squish,
                   organization: "Theater unter Sternen", source: :scraper)
    end
  end

  # The event rows show no year ("27.06."), but the intro names the festival
  # period ("27.06. - 11.07.2026") — that year applies to the whole programme.
  def self.festival_year(document)
    match = document.text.match(/\d{1,2}\.\d{1,2}\.\s*[-–]\s*\d{1,2}\.\d{1,2}\.(\d{4})/)
    raise "no festival period found on #{URL}" if match.nil?

    match[1].to_i
  end
end
