class RefetchAll
  def self.call
    Event.destroy_all

    FetchTreibhaus.call
    FetchLeokino.call
    FetchTheaterPraesent.call
  end
end
