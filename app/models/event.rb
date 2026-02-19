class Event < ApplicationRecord
  ORGANIZATIONS_BY_TYPE = {
    'Kino': [ "Leokino" ],
    'Theater': [ "Theater Praesent", "Haus der Musik", "Brux", "Tiroler Landestheater", "Kellertheater" ],
    'Musik und Kultur': [ "Treibhaus", "Die Bäckerei", "Innsbruck Music Hall" ],
    'Andere': [ "Andere" ]
  }
  ORGANIZATIONS = ORGANIZATIONS_BY_TYPE.values.flatten.uniq

  enum :source, { scraper: 0, webform: 1 }

  validates :name, :location, :datetime, :link, presence: true
  validates :name, uniqueness: { scope: [ :datetime, :organization ] }
  validates :organization, inclusion: { in: ORGANIZATIONS }

  scope :published, -> { where.not(approved_at: nil).or(where(source: :scraper)) }
  scope :to_approve, -> { where(approved_at: nil).where(source: :webform) }
  scope :approved, -> { where.not(approved_at: nil) }

  def date = datetime.to_date

  def source_enum = [ :scraper, :webform ] # for rails_admin
end
