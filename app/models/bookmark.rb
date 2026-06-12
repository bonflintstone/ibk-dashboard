# A single bookmarked event, stored as the client-side event key
# (name|datetime|organization — the events table's uniqueness constraint)
# instead of an event id, so bookmarks survive the scrapers destroying and
# re-importing events on every run.
class Bookmark < ApplicationRecord
  belongs_to :bookmark_list

  validates :event_key, presence: true, uniqueness: { scope: :bookmark_list_id }
end
