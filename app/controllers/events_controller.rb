class EventsController < ApplicationController
  def index
    # refetch once a day on the first request
    RefetchAll.call unless RefetchEvent.where(created_at: Date.today.beginning_of_day..).exists?

    @events = Event.all.order(datetime: :asc)
    @refetch_event = RefetchEvent.last
  end
end
