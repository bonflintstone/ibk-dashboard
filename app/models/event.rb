class Event < ApplicationRecord
  validates :name, :location, :datetime, :link, presence: true
  validates :organization, inclusion: { in: ["Leokino", "Theater Praesent", "Treibhaus", "Die Bäckerei"] }

  validates :name, uniqueness: { scope: :datetime }

  def date = datetime.to_date
end
