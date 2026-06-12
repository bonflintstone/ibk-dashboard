# An anonymous, login-free bookmark collection. The token is the only
# credential: it lives in the browser's localStorage and in sync links/QR
# codes, and whoever has it reads and writes the list.
class BookmarkList < ApplicationRecord
  has_secure_token :token

  has_many :bookmarks, dependent: :destroy

  def keys = bookmarks.pluck(:event_key)

  # The bookmarked events that still exist in the database. Keys can't be
  # parsed back into columns (names may contain the separator), so match by
  # computing each event's key — fine at this table's size.
  def events
    wanted = keys.to_set
    Event.published.order(:datetime).select { |event| wanted.include?(event.bookmark_key) }
  end
end
