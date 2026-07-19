# Leokino's Open Air Kino im Zeughaus shows one film per evening throughout
# August; the festival page lists the whole programme of the current season.
class FetchLeokinoOpenAir
  URL = "https://www.leokino.at/festivals/open-air-kino-im-zeughaus/"

  DESCRIPTION = "Open Air Kino im Zeughaushof. Filmstart bei Einbruch der Dunkelheit, Einlass 90 Minuten davor."
  TOUR_NOTE = " Eine Stunde vor Filmbeginn gibt es eine kostenlose Führung durchs Zeughaus."

  def self.call
    document = Nokogiri::HTML(HTTParty.get(URL).body)
    year = season_year(document)

    document.css('a[href*="/film/"]').map do |link|
      # Programme entries read "Sa. 01.08. Spaceballs", a trailing * marks a
      # free guided tour before the film. Film links elsewhere on the page
      # (teasers, navigation) don't match the date pattern and are skipped.
      match = link.text.squish.match(/\A[[:alpha:]]{2}\.\s*(\d{1,2})\.(\d{1,2})\.\s*(.+?)\s*(\*)?\z/)
      next if match.nil?

      # "Start bei Einbruch der Dunkelheit" — there is no fixed time; 21:00
      # approximates nightfall in August.
      datetime = Time.zone.local(year, match[2].to_i, match[1].to_i, 21, 0)
      # The programme stays online after the season; then every date is past
      # and the scrape legitimately yields no events.
      next if datetime < Time.zone.now.beginning_of_day

      Event.create(datetime:, name: match[3], location: "Zeughaus",
                   link: URI.join(URL, link["href"]).to_s,
                   description: match[4] ? DESCRIPTION + TOUR_NOTE : DESCRIPTION,
                   organization: "Leokino Open Air", category: "Kultur", source: :scraper)
    end
  end

  # The programme entries show no year ("01.08."), but the page header names
  # the season ("August 2026") — that year applies to the whole programme.
  def self.season_year(document)
    match = document.text.match(/August\s+(\d{4})/)
    raise "no season year found on #{URL}" if match.nil?

    match[1].to_i
  end
end
