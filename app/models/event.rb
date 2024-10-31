class Event < ApplicationRecord
  ORGANIZATIONS_BY_TYPE = {
    'Kino': [ "Leokino" ],
    'Theater': [ "Theater Praesent", "Haus der Musik", "Brux", "Tiroler Landestheater" ],
    'Musik und Kultur': [ "Treibhaus", "Die Bäckerei" ]
  }
  ORGANIZATIONS = ORGANIZATIONS_BY_TYPE.values.flatten.uniq

  validates :name, :location, :datetime, :link, presence: true
  validates :organization, inclusion: { in: ORGANIZATIONS }

  validates :name, uniqueness: { scope: :datetime }

  def date = datetime.to_date
end
