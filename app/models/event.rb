class Event < ApplicationRecord
  ORGANIZATIONS = [ "Leokino", "Theater Praesent", "Treibhaus", "Die Bäckerei", "Haus der Musik" ]

  validates :name, :location, :datetime, :link, presence: true
  validates :organization, inclusion: { in: ORGANIZATIONS }

  validates :name, uniqueness: { scope: :datetime }

  def date = datetime.to_date
end
