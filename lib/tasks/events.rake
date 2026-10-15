namespace :events do
  # Overwrites in place rather than clearing first, so the site never shows
  # everything as "Andere" mid-run and a failed batch keeps its old categories.
  desc "Re-run categorization for all upcoming events (e.g. after changing Event::CATEGORIES)"
  task recategorize: :environment do
    upcoming = Event.where(datetime: Date.current.beginning_of_day..)
    CategorizeEvents.call(upcoming)
    puts upcoming.group(:category).count.inspect
  end
end
