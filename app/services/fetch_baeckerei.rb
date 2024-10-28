class FetchBaeckerei
  def self.call
    response = HTTParty.get('https://diebaeckerei.at/programm')
    document = Nokogiri::HTML(response.body)

    document.css('.events-list-item').map do |event_row|
      day = event_row.css('.event-thumb__day').text.strip.sub(/..$/, '20\0')

      next unless day.present?

      time = event_row.css('.event-thumb__time').text
      datetime = Time.parse("#{day} #{time}")

      location = 'Die Bäckerei'
      name = event_row.css('.event-thumb__title').text.strip
      link = event_row.css('a.event-thumb').attr('href').value
      description = event_row.css('.event-thumb__excerpt').text.strip

      Event.create(datetime:, location:, name:, link:, description:, organization: 'Die Bäckerei').valid?
    end
  end
end
