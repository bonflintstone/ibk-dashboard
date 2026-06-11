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
    "Innsbruck Music Hall" => FetchMusichall,
    "SNKTBRTLM" => FetchSnktbrtlm,
    "Gans Anders" => FetchGansAnders
  }.freeze

  # Venues with only a handful of events per year — an empty scrape is
  # legitimate there and doesn't indicate a broken scraper.
  EMPTY_ALLOWED = [ "SNKTBRTLM", "Gans Anders" ].freeze

  class EmptyScrape < StandardError; end

  def self.call
    SCRAPERS.each_key { |organization| refetch(organization) }

    InstagramProfile.order(:organization).pluck(:organization).each_with_index do |organization, index|
      pause(15) if index.positive?
      refetch(organization)
    end

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
          if Event.where(source: :scraper, organization:).none? && EMPTY_ALLOWED.exclude?(organization)
            raise EmptyScrape, "scraper returned 0 events"
          end
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

  # Spaces out requests so Instagram doesn't rate-limit the run (429).
  def self.pause(seconds) = sleep(seconds)
end
