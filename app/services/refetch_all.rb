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
    organizations.each { |organization| refetch(organization) }

    RefetchEvent.create(new_event_count: Event.count)
  end

  # Every refetchable organization: static scrapers plus Instagram profiles.
  def self.organizations
    SCRAPERS.keys + InstagramProfile.order(:organization).pluck(:organization)
  end

  def self.refetch(organization)
    if (fetcher = SCRAPERS[organization])
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
    else
      # FetchInstagram replaces a profile's events transactionally itself, so
      # it can skip the Claude API call when nothing was posted. Unlike the
      # scrapers above, 0 extracted events counts as a successful run.
      profile = InstagramProfile.find_by!(organization:)
      ScraperRun.record(organization) { FetchInstagram.call(profile) }
    end
  end
end
