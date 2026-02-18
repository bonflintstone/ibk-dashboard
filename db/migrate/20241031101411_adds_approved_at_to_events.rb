class AddsApprovedAtToEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :approved_at, :datetime
    add_column :events, :source, :integer, default: 0
  end
end
