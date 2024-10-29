module ApplicationHelper
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
    end
  end
end
