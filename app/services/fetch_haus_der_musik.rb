class FetchHausDerMusik
  def self.call
    response = HTTParty.get("https://www.haus-der-musik-innsbruck.at/kalender/")
    document = Nokogiri::HTML(response.body)

    document.css('.EventList article').map do |event_row|
      datetime = event_row.css('time').attr('datetime')&.then(&Time.method(:parse))
      next unless datetime.present? 

      name = event_row.css('h2.title-5').text.strip
      description = event_row.css('.info span:first-child').text
      location = event_row.css('.stats .stat:nth-child(2) strong').text
      link = 'https://www.haus-der-musik-innsbruck.at' + event_row.css('.info a').attr('href').value

      Event.create(datetime:, location:, name:, link:, description:, organization: 'Haus der Musik').errors
    end
  end
end
