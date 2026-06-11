class InstagramProfile < ApplicationRecord
  validates :username, :organization, :location, presence: true
  validates :username, uniqueness: true

  def url = "https://www.instagram.com/#{username}/"
end
