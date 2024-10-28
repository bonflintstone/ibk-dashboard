class CreateEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :events do |t|
      t.string :name
      t.string :location
      t.datetime :datetime
      t.string :description
      t.string :link
      t.string :organization

      t.timestamps
    end
  end
end
