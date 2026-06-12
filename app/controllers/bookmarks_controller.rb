# JSON API behind the browser-side bookmark store. There are no accounts:
# a BookmarkList's token is the only credential (see BookmarkList).
class BookmarksController < ApplicationController
  def show
    list = BookmarkList.find_by(token: params[:token])
    return head :not_found if list.nil?

    render json: { token: list.token, keys: list.keys }
  end

  # Adds and removes keys. An unknown or missing token creates a fresh list,
  # so a first-time browser (or one whose list got lost) heals itself — the
  # client always adopts the returned token.
  def update
    list = BookmarkList.find_by(token: params[:token]) || BookmarkList.create!
    Array(params[:add]).each { |key| list.bookmarks.find_or_create_by(event_key: key) }
    list.bookmarks.where(event_key: Array(params[:remove])).destroy_all

    render json: { token: list.token, keys: list.keys }
  end

  # Device sync: pour this browser's list into the one from the scanned
  # link, which both devices share from then on.
  def merge
    target = BookmarkList.find_by(token: params[:other])
    return head :not_found if target.nil?

    source = BookmarkList.find_by(token: params[:token])
    if source && source != target
      source.keys.each { |key| target.bookmarks.find_or_create_by(event_key: key) }
      source.destroy
    end

    render json: { token: target.token, keys: target.keys }
  end

  def qr
    list = BookmarkList.find_by(token: params[:token])
    return head :not_found if list.nil?

    svg = RQRCode::QRCode.new(root_url(sync: list.token))
      .as_svg(module_size: 6, use_path: true, viewbox: true)
    render plain: svg, content_type: "image/svg+xml"
  end
end
