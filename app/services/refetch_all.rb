class RefetchAll
  SCRAPERS = {
    "Treibhaus" => FetchTreibhaus,
    "Theater Praesent" => FetchTheaterPraesent,
    "Kellertheater" => FetchKellertheater,
    "Die Bäckerei" => FetchBaeckerei,
    "Haus der Musik" => FetchHausDerMusik,
    "Brux" => FetchBrux,
    "Tiroler Landestheater" => FetchTirolerLandestheater,
    "Innsbruck Music Hall" => FetchMusichall,
    "SNKTBRTLM" => FetchSnktbrtlm,
    "Gans Anders" => FetchGansAnders,
    "Montagu" => FetchMontagu,
    "Theater unter Sternen" => FetchTheaterUnterSternen,
    "PMK" => FetchPmk,
    "Leokino Open Air" => FetchLeokinoOpenAir
  }.freeze

  # Venues with only a handful of events per year — an empty scrape is
  # legitimate there and doesn't indicate a broken scraper. Theater unter
  # Sternen and the Leokino Open Air are summer festivals, empty outside
  # their season.
  EMPTY_ALLOWED = [ "SNKTBRTLM", "Gans Anders", "Theater unter Sternen", "Leokino Open Air" ].freeze

  # Instagram is fetched through a paid residential proxy and Meta blocks
  # aggressively; the profiles post rarely, so each one is only refetched
  # every three days. A failed fetch leaves fetched_at untouched and is
  # retried on the next daily run; manual refetches from the status page
  # (RefetchAll.refetch) are never throttled.
  INSTAGRAM_FETCH_INTERVAL = 3.days

  class EmptyScrape < StandardError; end

  def self.call
    SCRAPERS.each_key { |organization| refetch(organization) }

    due_instagram_organizations.each_with_index do |organization, index|
      pause(15) if index.positive?
      refetch(organization)
    end

    # Sweep for anything the per-organization runs left behind
    # (webform submissions, failed categorization calls).
    categorize(Event.where(category: nil))

    RefetchEvent.create(new_event_count: Event.count)
  end

  # Every refetchable organization: static scrapers plus Instagram profiles.
  def self.organizations
    SCRAPERS.keys + InstagramProfile.order(:organization).pluck(:organization)
  end

  def self.due_instagram_organizations
    InstagramProfile.order(:organization)
      .where("fetched_at IS NULL OR fetched_at <= ?", INSTAGRAM_FETCH_INTERVAL.ago)
      .pluck(:organization)
  end

  def self.refetch(organization)
    if (fetcher = SCRAPERS[organization])
      ScraperRun.record(organization) do
        # If the scraper raises, the rollback keeps the previously
        # scraped events instead of leaving the organization empty.
        # 0 scraped events counts as broken (e.g. site redesign).
        Event.transaction do
          scraped = Event.where(source: :scraper, organization:)
          known_categories = scraped.where.not(category: nil).pluck(:name, :category)
          scraped.destroy_all
          fetcher.call
          if scraped.none? && EMPTY_ALLOWED.exclude?(organization)
            raise EmptyScrape, "scraper returned 0 events"
          end
          restore_categories(scraped, known_categories)
        end
      end
    else
      # FetchInstagram replaces a profile's events transactionally itself, so
      # it can skip the Claude API call when nothing was posted. Unlike the
      # scrapers above, 0 extracted events counts as a successful run.
      profile = InstagramProfile.find_by!(organization:)
      ScraperRun.record(organization) { FetchInstagram.call(profile) }
    end

    categorize(Event.where(organization:, category: nil))
  end

  # Every refetch recreates the scraped events, so without this each one would
  # be sent to Claude again every day. An event that comes back under the same
  # name keeps its category; only genuinely new events get categorized.
  def self.restore_categories(events, known_categories)
    known_categories.group_by(&:last).each do |category, pairs|
      events.where(category: nil, name: pairs.map(&:first)).update_all(category:)
    end
  end

  # A failed categorization must not fail the (already committed) scrape —
  # the events stay uncategorized and are retried on the next run. It is
  # still reported (→ Bugsink), otherwise every event silently shows "Andere".
  def self.categorize(events)
    CategorizeEvents.call(events)
  rescue StandardError => error
    Rails.error.report(error, handled: true, context: { service: "CategorizeEvents" })
  end

  # Spaces out requests so Instagram doesn't rate-limit the run (429).
  def self.pause(seconds) = sleep(seconds)
end
