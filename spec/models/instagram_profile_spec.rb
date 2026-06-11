require "rails_helper"

RSpec.describe InstagramProfile do
  def build_profile(attributes = {})
    InstagramProfile.new(
      { username: "arche.ahoi", organization: "Arche Ahoi", location: "Bogen 30" }.merge(attributes)
    )
  end

  it "is valid with username, organization and location" do
    expect(build_profile).to be_valid
  end

  it "requires a unique username" do
    build_profile.save!

    expect(build_profile(organization: "Andere Orga")).not_to be_valid
  end
end
