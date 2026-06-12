class Event < ApplicationRecord
  # Every event is assigned one of these by the Claude API (CategorizeEvents,
  # or FetchInstagram during extraction). nil means "not categorized yet" and
  # is displayed as "Andere" until the next categorization run.
  CATEGORIES = [ "Theater", "Konzerte", "Party", "Kultur", "Workshop", "Politik", "Andere" ].freeze

  ORGANIZATIONS = [
    "Theater Praesent", "Brux", "Tiroler Landestheater", "Kellertheater",
    "Treibhaus", "Die Bäckerei", "Innsbruck Music Hall", "Haus der Musik",
    "SNKTBRTLM", "Gans Anders", "Montagu", "Andere"
  ].freeze

  # ORGANIZATIONS plus the organizations scraped via InstagramProfile.
  def self.organizations = ORGANIZATIONS + InstagramProfile.order(:organization).pluck(:organization)

  enum :source, { scraper: 0, webform: 1 }

  validates :name, :location, :datetime, :link, presence: true
  validates :name, uniqueness: { scope: [ :datetime, :organization ] }
  validates :organization, inclusion: { in: ->(_event) { Event.organizations } }
  validates :category, inclusion: { in: CATEGORIES }, allow_nil: true
  # Webform submissions in the past would be saved but never shown (the
  # dashboard only lists today onward), so reject them at the source. Scrapers
  # are exempt — they legitimately re-import events on their start day.
  validate :datetime_not_in_past, on: :create, if: :webform?

  scope :published, -> { where.not(approved_at: nil).or(where(source: :scraper)) }
  scope :to_approve, -> { where(approved_at: nil).where(source: :webform) }
  scope :approved, -> { where.not(approved_at: nil) }

  def date = datetime.to_date

  def display_category = category || "Andere"

  def source_enum = [ :scraper, :webform ] # for rails_admin
  def category_enum = CATEGORIES # for rails_admin

  private

  def datetime_not_in_past
    return if datetime.blank? || datetime >= Date.current.beginning_of_day

    errors.add(:datetime, "darf nicht in der Vergangenheit liegen")
  end
end
