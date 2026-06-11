module ApplicationHelper
  ORGANIZATION_COLOR_KEYS = {
    "Treibhaus" => "blue",
    "Theater Praesent" => "yellow",
    "Die Bäckerei" => "green",
    "Haus der Musik" => "purple",
    "Brux" => "pink",
    "Kellertheater" => "orange",
    "Innsbruck Music Hall" => "teal",
    "Tiroler Landestheater" => "indigo",
    "Andere" => "gray"
  }.freeze

  # Stable fallback palette for organizations added at runtime (e.g. Instagram profiles).
  # Tailwind only compiles classes it finds in the source, so the full class
  # names are spelled out in the two methods below.
  FALLBACK_COLOR_KEYS = %w[rose sky lime amber violet cyan fuchsia emerald].freeze

  def organization_accent_color(organization)
    case organization_color_key(organization)
    when "red" then "bg-red-400"
    when "blue" then "bg-blue-400"
    when "yellow" then "bg-yellow-400"
    when "green" then "bg-green-400"
    when "purple" then "bg-purple-400"
    when "pink" then "bg-pink-400"
    when "orange" then "bg-orange-400"
    when "teal" then "bg-teal-400"
    when "indigo" then "bg-indigo-400"
    when "rose" then "bg-rose-400"
    when "sky" then "bg-sky-400"
    when "lime" then "bg-lime-400"
    when "amber" then "bg-amber-400"
    when "violet" then "bg-violet-400"
    when "cyan" then "bg-cyan-400"
    when "fuchsia" then "bg-fuchsia-400"
    when "emerald" then "bg-emerald-400"
    else "bg-gray-400"
    end
  end

  def organization_color(organization)
    case organization_color_key(organization)
    when "red" then "bg-red-100"
    when "blue" then "bg-blue-100"
    when "yellow" then "bg-yellow-100"
    when "green" then "bg-green-100"
    when "purple" then "bg-purple-100"
    when "pink" then "bg-pink-100"
    when "orange" then "bg-orange-100"
    when "teal" then "bg-teal-100"
    when "indigo" then "bg-indigo-100"
    when "rose" then "bg-rose-100"
    when "sky" then "bg-sky-100"
    when "lime" then "bg-lime-100"
    when "amber" then "bg-amber-100"
    when "violet" then "bg-violet-100"
    when "cyan" then "bg-cyan-100"
    when "fuchsia" then "bg-fuchsia-100"
    when "emerald" then "bg-emerald-100"
    else "bg-gray-100"
    end
  end

  private

  def organization_color_key(organization)
    ORGANIZATION_COLOR_KEYS[organization] ||
      FALLBACK_COLOR_KEYS[organization.to_s.sum % FALLBACK_COLOR_KEYS.size]
  end
end
