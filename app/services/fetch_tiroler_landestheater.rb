class FetchTirolerLandestheater
  BASE_URL = "https://www.landestheater.at"
  SCHEDULE_CONFIG_ID = 37802 # from data-schedule-configid on /kalender/

  # The calendar is rendered client-side; this is the JSON API it talks to.
  def self.call
    page = 1

    loop do
      response = HTTParty.get("#{BASE_URL}/dynamic-search/schedule/j-schedule", query: {
        configId: SCHEDULE_CONFIG_ID,
        startDate: Time.zone.today.beginning_of_day.to_i,
        endDate: 2.months.from_now.end_of_day.to_i,
        page:
      })

      data = JSON.parse(response.body).fetch("activitiesData")

      data.fetch("activities").each_value do |activities|
        activities.each do |activity|
          Event.create(
            datetime: Time.zone.at(activity.fetch("start")),
            name: activity.fetch("title"),
            link: URI.join(BASE_URL, activity["production_link"].presence || "/kalender/").to_s,
            location: activity["stage"].presence || "Tiroler Landestheater",
            description: [ activity["activityType"], activity["description"] ].compact_blank.join(" — "),
            organization: "Tiroler Landestheater",
            source: :scraper
          )
        end
      end

      break if page * data.fetch("per_page") >= data.fetch("total_count") || page >= 10
      page += 1
    end
  end
end
