class RefetchEvent < ApplicationRecord
  validates :new_event_count, presence: true
end
