class FetchMusikHall
  def self.call
    response = HTTParty.get("https://music-hall.at/veranstaltungen/aktuelleveranstaltungen.html")
    document = Nokogiri::HTML(response.body)

    binding.irb

    # date row followed by event rows
    document.css("table.fc-list-table tr").map do |table_row|
      puts table_row.text
      date_attr = table_row.attribute("date-date")

      # set date and skip to next row
      next @date = Date.parse(date_attr.value) if date_attr

      time = table_row.css("td:first-child").text[/(\d\d:\d\d)/]
      datetime = Time.parse("#{@date} #{time}", "%Y-%m-%d %H:%M")

      puts datetime
    end
  end
end
