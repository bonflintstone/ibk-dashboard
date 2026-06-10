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

  def new
    @event = Event.new
  end

  def create
    @event = Event.new(event_params.merge(source: :webform, organization: "Andere"))

    if @event.save
      redirect_to root_path, flash: { notice: "Thanks for your submission. We will check it and then it will go online" }
    else
      render :new
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
