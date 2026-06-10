module ApplicationHelper
  def organization_accent_color(organization)
    case organization
    when "Leokino"
      "bg-red-400"
    when "Treibhaus"
      "bg-blue-400"
    when "Theater Praesent"
      "bg-yellow-400"
    when "Die Bäckerei"
      "bg-green-400"
    when "Haus der Musik"
      "bg-purple-400"
    when "Brux"
      "bg-pink-400"
    when "Kellertheater"
      "bg-orange-400"
    when "Innsbruck Music Hall"
      "bg-teal-400"
    when "Tiroler Landestheater"
      "bg-indigo-400"
    when "Andere"
      "bg-gray-400"
    end
  end

  def organization_color(organization)
    case organization
    when "Leokino"
      "bg-red-100"
    when "Treibhaus"
      "bg-blue-100"
    when "Theater Praesent"
      "bg-yellow-100"
    when "Die Bäckerei"
      "bg-green-100"
    when "Haus der Musik"
      "bg-purple-100"
    when "Brux"
      "bg-pink-100"
    when "Kellertheater"
      "bg-orange-100"
    when "Innsbruck Music Hall"
      "bg-teal-100"
    when "Tiroler Landestheater"
      "bg-indigo-100"
    when "Andere"
      "bg-gray-100"
    end
  end
end
