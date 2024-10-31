class Event < ApplicationRecord
  ORGANIZATIONS_BY_TYPE = {
    'Kino': [ "Leokino" ],
    'Theater': [ "Theater Praesent", "Haus der Musik", "Brux", "Tiroler Landestheater" ],
    'Musik und Kultur': [ "Treibhaus", "Die Bäckerei" ]
  }
  ORGANIZATIONS = ORGANIZATIONS_BY_TYPE.values.flatten.uniq

  validates :name, :location, :datetime, :link, presence: true
  validates :name, uniqueness: { scope: [:datetime, :organization] }

  scope :published, -> { where.not(approved_at: nil).or(where(source: :scraper)) }

  def date = datetime.to_date
end
