class CreateVisits < ActiveRecord::Migration[8.0]
  def change
    create_table :visits do |t|
      t.date :week, null: false
      t.string :visitor_digest, null: false

      t.timestamps
    end

    add_index :visits, [ :week, :visitor_digest ], unique: true
  end
end
