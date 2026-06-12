# An anonymous, login-free bookmark collection. The token is the only
# credential: it lives in the browser's localStorage and in sync links/QR
# codes, and whoever has it reads and writes the list.
class BookmarkList < ApplicationRecord
  has_secure_token :token

  has_many :bookmarks, dependent: :destroy

  def keys = bookmarks.pluck(:event_key)
end
