# Генерит iCalendar (.ics) текст по RFC 5545 — без внешних gem'ов, чтобы
# не тащить icalendar (~50KB transitive deps).
#
# Использование:
#   ics = IcalendarBuilder.new(prod_id: "HRMS")
#         .add_event(uid:, summary:, start_at:, end_at:, description:, location:)
#         .to_s
#   send_data ics, type: "text/calendar; charset=utf-8", filename: "hrms.ics"
#
# Поддерживается:
#   • VEVENT с DTSTART/DTEND в UTC
#   • SUMMARY / DESCRIPTION / LOCATION / URL / UID
#   • Escape специальных символов (\\, , , ;, перенос)
#   • Fold длинных строк до 75 chars (RFC 5545 §3.1)
class IcalendarBuilder
  def initialize(prod_id: "HRMS")
    @prod_id = prod_id
    @events  = []
  end

  def add_event(uid:, summary:, start_at:, end_at:, description: nil, location: nil, url: nil)
    @events << {
      uid:         uid.to_s,
      summary:     summary.to_s,
      start_at:    start_at,
      end_at:      end_at,
      description: description.to_s,
      location:    location.to_s,
      url:         url.to_s
    }
    self
  end

  def to_s
    lines = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//#{@prod_id}//EN",
      "CALSCALE:GREGORIAN",
      "METHOD:PUBLISH"
    ]
    @events.each { |ev| lines.concat(build_event(ev)) }
    lines << "END:VCALENDAR"
    lines.map { |l| fold(l) }.join("\r\n") + "\r\n"
  end

  private

  def build_event(ev)
    out = [ "BEGIN:VEVENT" ]
    out << "UID:#{ev[:uid]}"
    out << "DTSTAMP:#{fmt_utc(Time.current)}"
    out << "DTSTART:#{fmt_utc(ev[:start_at])}"
    out << "DTEND:#{fmt_utc(ev[:end_at])}"
    out << "SUMMARY:#{escape(ev[:summary])}"
    out << "DESCRIPTION:#{escape(ev[:description])}"      if ev[:description].present?
    out << "LOCATION:#{escape(ev[:location])}"            if ev[:location].present?
    out << "URL:#{escape(ev[:url])}"                      if ev[:url].present?
    out << "END:VEVENT"
    out
  end

  # YYYYMMDDTHHmmssZ
  def fmt_utc(time)
    time.utc.strftime("%Y%m%dT%H%M%SZ")
  end

  # RFC 5545 §3.3.11 — escape special chars в TEXT.
  def escape(text)
    text.to_s
        .gsub("\\", "\\\\")
        .gsub("\r\n", "\\n")
        .gsub("\n", "\\n")
        .gsub(",", "\\,")
        .gsub(";", "\\;")
  end

  # RFC 5545 §3.1 — длинные строки фолдятся на 75 octets с continuation-space.
  def fold(line)
    return line if line.bytesize <= 75
    out = []
    rest = line.dup
    out << rest.byteslice(0, 75)
    rest = rest.byteslice(75, rest.bytesize - 75)
    while rest && !rest.empty?
      chunk = rest.byteslice(0, 74)
      out << " #{chunk}"
      rest = rest.byteslice(74, rest.bytesize - 74)
    end
    out.join("\r\n")
  end
end
