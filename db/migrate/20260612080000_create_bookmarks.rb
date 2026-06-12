class CreateBookmarks < ActiveRecord::Migration[8.0]
  def change
    create_table :bookmark_lists do |t|
      t.string :token, null: false
      t.timestamps
      t.index :token, unique: true
    end

    create_table :bookmarks do |t|
      t.references :bookmark_list, null: false, foreign_key: true
      t.string :event_key, null: false
      t.timestamps
      t.index [ :bookmark_list_id, :event_key ], unique: true
    end
  end
end
