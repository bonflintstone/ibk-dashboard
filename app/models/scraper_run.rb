class ScraperRun < ApplicationRecord
  enum :status, { success: 0, failure: 1 }

  # Runs the given block for one scraper and records the outcome.
  # A raising scraper is recorded as a failure but never re-raises,
  # so the remaining scrapers still run.
  def self.record(scraper)
    started_at = Time.current
    yield
    create!(
      scraper:,
      status: :success,
      events_count: Event.where(source: :scraper, organization: scraper).count,
      duration_ms: ((Time.current - started_at) * 1000).round
    )
  rescue StandardError => error
    create!(
      scraper:,
      status: :failure,
      error_class: error.class.name,
      error_message: error.message.to_s.truncate(1000),
      duration_ms: ((Time.current - started_at) * 1000).round
    )
  end
end
