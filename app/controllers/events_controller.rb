class EventsController < ApplicationController
  def index
    @events = Event.all.order(datetime: :asc)
  end
end
