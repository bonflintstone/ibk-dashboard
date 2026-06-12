# Renders events as an iCalendar (RFC 5545) document, used for the personal
# bookmark calendar feed that Apple Calendar & co. subscribe to.
class IcsCalendar
  # Events carry no duration, so give calendar entries a plausible default.
  DEFAULT_DURATION = 2.hours

  def self.generate(events) = new(events).generate

  def initialize(events)
    @events = events
  end

  def generate
    lines = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//Ibk Dashboard//DE",
      "CALSCALE:GREGORIAN",
      "X-WR-CALNAME:Ibk Dashboard – Gemerkte Events",
      *@events.flat_map { |event| event_lines(event) },
      "END:VCALENDAR"
    ]
    lines.map { |line| fold(line) }.join("\r\n") + "\r\n"
  end

  private

  def event_lines(event)
    [
      "BEGIN:VEVENT",
      "UID:#{Digest::SHA256.hexdigest(event.bookmark_key)}@ibk-dashboard",
      "DTSTAMP:#{timestamp(event.updated_at)}",
      "DTSTART:#{timestamp(event.datetime)}",
      "DTEND:#{timestamp(event.datetime + DEFAULT_DURATION)}",
      "SUMMARY:#{escape(event.name)}",
      "LOCATION:#{escape(event.location)}",
      "DESCRIPTION:#{escape([ event.description, event.link ].compact_blank.join("\n\n"))}",
      "URL:#{escape(event.link)}",
      "END:VEVENT"
    ]
  end

  def timestamp(time) = time.utc.strftime("%Y%m%dT%H%M%SZ")

  def escape(text)
    text.to_s.gsub(/[\\;,\n]/, "\\" => "\\\\", ";" => "\\;", "," => "\\,", "\n" => "\\n")
  end

  # RFC 5545 caps content lines at 75 octets; continuations start with a space.
  def fold(line)
    return line if line.bytesize <= 75

    folded = +""
    length = 0
    line.each_char do |char|
      if length + char.bytesize > 75
        folded << "\r\n "
        length = 1
      end
      folded << char
      length += char.bytesize
    end
    folded
  end
end
