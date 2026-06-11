# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

InstagramProfile.find_or_create_by!(username: "arche.ahoi") do |profile|
  profile.organization = "Arche Ahoi"
  profile.location = "Bogen 30"
  profile.category = "Musik und Kultur"
end

InstagramProfile.find_or_create_by!(username: "pembau.art") do |profile|
  profile.organization = "Pembau"
  profile.location = "Kulturbauernhof Pembau"
  profile.category = "Musik und Kultur"
end

InstagramProfile.find_or_create_by!(username: "links_vom_inn") do |profile|
  profile.organization = "Links vom Inn"
  profile.location = "Innsbruck"
  profile.category = "Andere"
end
