xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom" do
  xml.channel do
    xml.title "Ibk Dashboard"
    xml.description "events around Innsbruck all in one place!"
    xml.link root_url
    xml.tag! "atom:link", href: feed_url, rel: "self", type: "application/rss+xml"
    xml.language "de"
    xml.lastBuildDate Time.current.rfc2822

    @events.each do |event|
      xml.item do
        xml.title "#{event.name} – #{event.datetime.strftime("%d.%m.%Y %H:%M")} – #{event.location}"
        xml.description event.description.presence || "#{event.name} am #{event.datetime.strftime("%d.%m.%Y %H:%M")}, #{event.location}"
        xml.link event.link
        xml.guid "ibk-dashboard:#{event.organization}:#{event.name}:#{event.datetime.iso8601}", isPermaLink: "false"
        xml.pubDate event.created_at.rfc2822
        xml.category event.organization
      end
    end
  end
end
