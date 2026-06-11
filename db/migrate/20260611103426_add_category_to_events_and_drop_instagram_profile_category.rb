class AddCategoryToEventsAndDropInstagramProfileCategory < ActiveRecord::Migration[8.0]
  def change
    # Events are categorized individually via the Claude API (CategorizeEvents),
    # so the per-venue category on InstagramProfile is obsolete.
    add_column :events, :category, :string
    remove_column :instagram_profiles, :category, :string, default: "Musik und Kultur", null: false
  end
end
