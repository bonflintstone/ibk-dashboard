class AddFetchedAtToInstagramProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :instagram_profiles, :fetched_at, :datetime
  end
end
