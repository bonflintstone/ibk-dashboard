class CreateInstagramProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :instagram_profiles do |t|
      t.string :username, null: false, index: { unique: true }
      t.string :organization, null: false
      t.string :location, null: false
      t.string :category, null: false, default: "Musik und Kultur"
      t.string :posts_digest

      t.timestamps
    end
  end
end
