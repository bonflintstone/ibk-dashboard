# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

[
  { username: "arche.ahoi", organization: "Arche Ahoi", location: "Bogen 30", category: "Musik und Kultur" },
  { username: "pembau.art", organization: "Pembau", location: "Kulturbauernhof Pembau", category: "Musik und Kultur" },
  { username: "links_vom_inn", organization: "Links vom Inn", location: "Innsbruck", category: "Politik" },
  { username: "montagu_bedxbeers", organization: "Montagu", location: "Höttingergasse 7", category: "Musik und Kultur" },
  { username: "tacheles_ibk", organization: "Tacheles", location: "Tacheles", category: "Musik und Kultur" }
].each do |attributes|
  InstagramProfile.find_or_initialize_by(username: attributes[:username])
    .update!(attributes.except(:username))
end
