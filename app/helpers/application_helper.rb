module ApplicationHelper
  def event_color(event)
    case event.organization
    when 'Leokino'
      'bg-red-100'
    when 'Treibhaus'
      'bg-blue-100'
    when 'Theater Praesent'
      'bg-yellow-100'
    when 'Die Bäckerei'
      'bg-green-100'
    end
  end
end
