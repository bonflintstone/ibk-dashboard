class EventsController < ApplicationController
  def index
    # refetch once a day on the first request
    RefetchAll.call unless RefetchEvent.where(created_at: Date.today.beginning_of_day..).exists?

    selected_organizations = params[:organizations] || Event::ORGANIZATIONS

    @event_filter = { organizations: selected_organizations }
    @events = Event.where(organization: selected_organizations).order(datetime: :asc)
    @refetch_event = RefetchEvent.last
  end
end
