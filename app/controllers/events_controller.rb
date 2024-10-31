class EventsController < ApplicationController
  def index
    # refetch once a day on the first request
    RefetchAll.call unless RefetchEvent.where(created_at: Date.today.beginning_of_day..).exists?

    selected_organizations = params[:organizations].presence || Event::ORGANIZATIONS

    @event_filter = { organizations: selected_organizations }
    @events = Event.published.where(organization: selected_organizations).order(datetime: :asc)
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

  def event_params
    params.require(:event).permit(:datetime, :location, :name, :link, :description, :organization)
  end
end
