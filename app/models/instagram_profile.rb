class InstagramProfile < ApplicationRecord
  CATEGORIES = Event::ORGANIZATIONS_BY_TYPE.keys.map(&:to_s)

  validates :username, :organization, :location, presence: true
  validates :username, uniqueness: true
  validates :category, inclusion: { in: CATEGORIES }

  def url = "https://www.instagram.com/#{username}/"
end
