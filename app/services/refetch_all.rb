class RefetchAll
  def self.call
    Event.destroy_all

    FetchTreibhaus.call
    FetchLeokino.call
    FetchTheaterPraesent.call
    FetchBaeckerei.call
    FetchHausDerMusik.call
    FetchBrux.call

    RefetchEvent.create(new_event_count: Event.count)
  end
end
