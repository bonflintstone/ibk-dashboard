class AddsApprovedAtToEvents < ActiveRecord::Migration[7.2]
  def change
    create_enum :event_source, %w[scraper webform]

    add_column :events, :approved_at, :datetime
    add_column :events, :source, :event_source

    Event.update_all(source: :scraper)

    change_column_null :events, :source, false
  end
end
