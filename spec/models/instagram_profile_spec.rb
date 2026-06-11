require "rails_helper"

RSpec.describe InstagramProfile do
  def build_profile(attributes = {})
    InstagramProfile.new(
      { username: "arche.ahoi", organization: "Arche Ahoi",
        location: "Bogen 30", category: "Musik und Kultur" }.merge(attributes)
    )
  end

  it "is valid with username, organization, location and a known category" do
    expect(build_profile).to be_valid
  end

  it "requires a unique username" do
    build_profile.save!

    expect(build_profile(organization: "Andere Orga")).not_to be_valid
  end

  it "rejects unknown categories" do
    expect(build_profile(category: "Sport")).not_to be_valid
  end
end
