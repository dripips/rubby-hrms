# Письма про документы. Сейчас одно — уведомление об истечении.
# Noticed v3 вызывает mailer.with(params).method без аргументов; всё пришло
# через `params` (notification + recipient + явные поля из notifier).
class DocumentMailer < ApplicationMailer
  def expiring
    @recipient  = params[:recipient]
    document_id = params[:document_id]
    @document   = Document.kept.find_by(id: document_id) or return
    @days_left  = params[:days_left].to_i
    @owner_name = @document.documentable.try(:full_name) || "—"

    I18n.with_locale(@recipient&.locale.presence || I18n.default_locale) do
      subject_key = if @days_left < 0   then "document_mailer.expiring.subject_expired"
      elsif @days_left == 0 then "document_mailer.expiring.subject_today"
      elsif @days_left <= 7 then "document_mailer.expiring.subject_week"
      else                        "document_mailer.expiring.subject_month"
      end

      mail to: @recipient.email,
           subject: t(subject_key,
                       title:  @document.display_title,
                       owner:  @owner_name,
                       days:   @days_left.abs,
                       default: "Document «#{@document.display_title}» needs attention")
    end
  end
end
