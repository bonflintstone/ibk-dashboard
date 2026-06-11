module GermanDate
  MONTHS = {
    "jän" => 1, "jan" => 1, "feb" => 2, "mär" => 3, "apr" => 4, "mai" => 5,
    "jun" => 6, "jul" => 7, "aug" => 8, "sep" => 9, "okt" => 10, "nov" => 11, "dez" => 12
  }.freeze

  # Parses the first German date in the given text, e.g. "Fr., 3. Juli 2026",
  # "SAMSTAG - 11.JULI 2026" or "24.9.2026". Returns nil if there is none.
  def self.parse(text, hour: 20, minute: 0)
    if (match = text.match(/(\d{1,2})\.(\d{1,2})\.(\d{4})/))
      day, month, year = match[1].to_i, match[2].to_i, match[3].to_i
    elsif (match = text.match(/(\d{1,2})\.\s*([[:alpha:]]+)\.?\s*(\d{4})/))
      day, year = match[1].to_i, match[3].to_i
      month = MONTHS[match[2].downcase[0, 3]]
      return nil if month.nil?
    else
      return nil
    end

    Time.zone.local(year, month, day, hour, minute)
  rescue ArgumentError
    nil
  end
end
