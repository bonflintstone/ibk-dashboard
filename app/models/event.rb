class Event < ApplicationRecord
  ORGANIZATIONS_BY_TYPE = {
    'Kino': [ "Leokino" ],
    'Theater': [ "Theater Praesent", "Brux", "Tiroler Landestheater", "Kellertheater" ],
    'Musik und Kultur': [ "Treibhaus", "Die Bäckerei", "Innsbruck Music Hall", "Haus der Musik" ],
    'Politik': [],
    'Andere': [ "Andere" ]
  }

  # ORGANIZATIONS_BY_TYPE plus the organizations scraped via InstagramProfile.
  # Categories without any organization (yet) are hidden.
  def self.organizations_by_type
    InstagramProfile.pluck(:category, :organization)
      .each_with_object(ORGANIZATIONS_BY_TYPE.transform_values(&:dup)) do |(category, organization), by_type|
        organizations = (by_type[category.to_sym] ||= [])
        organizations << organization unless organizations.include?(organization)
      end
      .reject { |_category, organizations| organizations.empty? }
  end

  def self.organizations = organizations_by_type.values.flatten.uniq

  enum :source, { scraper: 0, webform: 1 }

  validates :name, :location, :datetime, :link, presence: true
  validates :name, uniqueness: { scope: [ :datetime, :organization ] }
  validates :organization, inclusion: { in: ->(_event) { Event.organizations } }

  scope :published, -> { where.not(approved_at: nil).or(where(source: :scraper)) }
  scope :to_approve, -> { where(approved_at: nil).where(source: :webform) }
  scope :approved, -> { where.not(approved_at: nil) }

  def date = datetime.to_date

  def source_enum = [ :scraper, :webform ] # for rails_admin
end
