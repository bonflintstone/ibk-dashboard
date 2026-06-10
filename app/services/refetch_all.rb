class RefetchAll
  SCRAPERS = {
    "Treibhaus" => FetchTreibhaus,
    "Leokino" => FetchLeokino,
    "Theater Praesent" => FetchTheaterPraesent,
    "Kellertheater" => FetchKellertheater,
    "Die Bäckerei" => FetchBaeckerei,
    "Haus der Musik" => FetchHausDerMusik,
    "Brux" => FetchBrux,
    "Tiroler Landestheater" => FetchTirolerLandestheater,
    "Innsbruck Music Hall" => FetchMusichall
  }.freeze

  class EmptyScrape < StandardError; end

  def self.call
    SCRAPERS.each do |organization, fetcher|
      ScraperRun.record(organization) do
        # If the scraper raises, the rollback keeps the previously
        # scraped events instead of leaving the organization empty.
        # 0 scraped events counts as broken (e.g. site redesign).
        Event.transaction do
          Event.where(source: :scraper, organization:).destroy_all
          fetcher.call
          raise EmptyScrape, "scraper returned 0 events" if Event.where(source: :scraper, organization:).none?
        end
      end
    end

    RefetchEvent.create(new_event_count: Event.count)
  end
end
