class Event < ApplicationRecord
  ORGANIZATIONS_BY_TYPE = {
    'Kino': [ "Leokino" ],
    'Theater': [ "Theater Praesent", "Haus der Musik", "Brux", "Tiroler Landestheater" ],
    'Musik und Kultur': [ "Treibhaus", "Die Bäckerei" ],
    'Andere': [ "Andere" ]
  }
  ORGANIZATIONS = ORGANIZATIONS_BY_TYPE.values.flatten.uniq

  validates :name, :location, :datetime, :link, presence: true
  validates :name, uniqueness: { scope: [:datetime, :organization] }
  validates :organization, inclusion: { in: ORGANIZATIONS }

  scope :published, -> { where.not(approved_at: nil).or(where(source: :scraper)) }
  scope :to_approve, -> { where(approved_at: nil).where(source: :webform) }
  scope :approved, -> { where.not(approved_at: nil) }

  def date = datetime.to_date

  def source_enum = [:scraper, :webform] # for rails_admin
end
