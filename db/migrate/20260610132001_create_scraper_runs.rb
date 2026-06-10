class CreateScraperRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :scraper_runs do |t|
      t.string :scraper, null: false
      t.integer :status, null: false, default: 0
      t.string :error_class
      t.text :error_message
      t.integer :events_count
      t.integer :duration_ms

      t.timestamps
    end

    add_index :scraper_runs, [ :scraper, :created_at ]
  end
end
