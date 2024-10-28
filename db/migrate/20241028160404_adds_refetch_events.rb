class AddsRefetchEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :refetch_events do |t|
      t.timestamps
      t.integer :new_event_count
    end
  end
end
