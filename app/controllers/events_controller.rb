class EventsController < ApplicationController
  after_action :track_visit, only: :index

  def index
    # filtering by organization happens client-side (events_controller.js)
    @events = Event
      .published
      .where(datetime: Date.today..)
      .order(datetime: :asc)
    @refetch_event = RefetchEvent.last
    # How many people have liked each event, keyed like Event#bookmark_key.
    @like_counts = Bookmark.group(:event_key).count
  end

  def feed
    @events = Event
      .published
      .where(datetime: Date.today..)
      .order(datetime: :asc)
  end

  def new
    @event = Event.new
  end

  # Fetches an event page and returns extracted form fields as JSON so the
  # submitter can review and correct them before submitting. The captcha is
  # checked before anything else — extraction burns Claude tokens.
  def extract
    unless captcha_passed?
      render json: { error: "Captcha-Prüfung fehlgeschlagen. Bitte versuche es erneut." }, status: :forbidden
      return
    end

    render json: ExtractEventFromLink.call(params[:link])
  rescue StandardError => error
    Rails.logger.warn("ExtractEventFromLink failed: #{error.class}: #{error.message}")
    render json: { error: "Konnte die Seite nicht auslesen. Bitte fülle die Felder manuell aus." }, status: :unprocessable_entity
  end

  def create
    unless captcha_passed?
      redirect_to root_path, flash: { alert: "Captcha-Prüfung fehlgeschlagen. Bitte versuche es erneut." }
      return
    end

    @event = Event.new(event_params.merge(source: :webform, organization: "Andere"))

    if @event.save
      ReviewEventJob.perform_later(@event)
      redirect_to root_path, flash: { notice: "Danke! Dein Event wird automatisch geprüft und ist gleich online." }
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  # How long a solved captcha stays valid for the rest of the submission flow.
  CAPTCHA_SESSION_TTL = 1.hour

  # hCaptcha tokens are single-use: extract consumes the token, so the
  # successful check is remembered in the session and create passes without
  # the submitter having to solve a second captcha.
  def captcha_passed?
    verified_at = session[:captcha_verified_at]
    return true if verified_at.present? && Time.zone.at(verified_at) > CAPTCHA_SESSION_TTL.ago

    return false unless Hcaptcha.verify?(params["h-captcha-response"], remote_ip: request.remote_ip)

    session[:captcha_verified_at] = Time.current.to_i
    true
  end

  def track_visit
    Visit.track(request)
  rescue StandardError => error
    Rails.logger.warn("Visit tracking failed: #{error.class}: #{error.message}")
  end

  def event_params
    params.require(:event).permit(:datetime, :location, :name, :link, :description, :organization)
  end
end
