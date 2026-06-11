class EventsController < ApplicationController
  after_action :track_visit, only: :index

  def index
    # filtering by organization happens client-side (events_controller.js)
    @events = Event
      .published
      .where(datetime: Date.today..)
      .order(datetime: :asc)
    @refetch_event = RefetchEvent.last
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

  def create
    unless Hcaptcha.verify?(params["h-captcha-response"], remote_ip: request.remote_ip)
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

  def track_visit
    Visit.track(request)
  rescue StandardError => error
    Rails.logger.warn("Visit tracking failed: #{error.class}: #{error.message}")
  end

  def event_params
    params.require(:event).permit(:datetime, :location, :name, :link, :description, :organization)
  end
end
