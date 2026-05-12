class Conversation < ApplicationRecord
  belongs_to :company
  belongs_to :creator,    class_name: "User"
  belongs_to :targetable, polymorphic: true, optional: true

  has_many :conversation_participants, dependent: :destroy
  has_many :participants, through: :conversation_participants, source: :user
  has_many :messages,    -> { order(:created_at) }, dependent: :destroy

  validates :subject, length: { maximum: 200 }

  scope :for_user, ->(user) {
    joins(:conversation_participants).where(conversation_participants: { user_id: user.id })
  }
  scope :recent, -> { order(Arel.sql("COALESCE(last_message_at, created_at) DESC")) }
  # Standalone — без привязки к сущности; контекстные прячем из общего списка
  # (они видны inline на странице самой сущности).
  scope :standalone, -> { where(targetable_type: nil) }

  # Возвращает existing 1-на-1 диалог или создаёт. Игнорирует context-bound треды.
  def self.between(*users)
    raise ArgumentError, "need ≥2 users" if users.size < 2
    company = users.first.employee&.company || Company.kept.first
    user_ids = users.map(&:id).sort

    candidate = standalone.for_user(users.first).joins(:conversation_participants)
                  .group("conversations.id")
                  .having("COUNT(conversation_participants.id) = ?", users.size)
                  .find_each
                  .find { |c| c.participants.pluck(:id).sort == user_ids }
    return candidate if candidate

    transaction do
      conv = create!(company: company, creator: users.first)
      users.each { |u| conv.conversation_participants.create!(user: u) }
      conv
    end
  end

  # Возвращает existing или создаёт context-bound discussion для сущности.
  # Участники подбираются автоматически per-type.
  def self.discussion_for(target, viewer)
    transaction do
      conv = find_or_initialize_by(targetable: target)
      if conv.new_record?
        conv.creator = viewer
        conv.company = (target.respond_to?(:company) && target.company) ||
                       viewer.employee&.company || Company.kept.first
        conv.subject = default_subject_for(target)
        conv.save!
      end
      # Добавляем viewer + auto-участников. Идемпотентно — повторный вызов
      # подтянет недавно появившихся участников (новый manager, например).
      (participants_for(target) | [ viewer ]).compact.uniq.each do |u|
        next if conv.conversation_participants.exists?(user_id: u.id)
        conv.conversation_participants.create!(user: u)
      end
      conv
    end
  end

  def self.participants_for(target)
    case target
    when LeaveRequest
      ([
        target.employee&.user,
        target.employee&.manager&.user
      ] + User.kept.where(role: %i[hr superadmin]).limit(3).to_a).compact.uniq
    when JobApplicant
      ([ target.owner ] + User.kept.where(role: %i[hr superadmin]).limit(3).to_a).compact.uniq
    else
      []
    end
  end

  def self.default_subject_for(target)
    case target
    when LeaveRequest
      "🌴 #{target.leave_type&.name} · #{target.started_on} → #{target.ended_on}"
    when JobApplicant
      "👤 #{target.full_name} · #{target.job_opening&.title}"
    else
      "Discussion"
    end
  end

  def title_for(viewer)
    return subject if subject.present?
    others = participants.where.not(id: viewer.id).limit(3).map(&:display_name)
    others.empty? ? I18n.t("chat.self_chat", default: "Заметки") : others.join(", ")
  end

  # Возвращает URL цели (для тэга в списке диалогов).
  def target_url
    return nil unless targetable
    helpers = Rails.application.routes.url_helpers
    case targetable
    when LeaveRequest then helpers.leave_request_path(targetable, anchor: "discussion")
    when JobApplicant then helpers.job_applicant_path(targetable, anchor: "discussion")
    end
  rescue StandardError
    nil
  end

  def target_label
    case targetable
    when LeaveRequest
      "🌴 Leave ##{targetable.id}"
    when JobApplicant
      "👤 #{targetable.full_name}"
    else
      targetable_type
    end
  end

  def last_message
    messages.last
  end

  def unread_count_for(user)
    participant = conversation_participants.find_by(user: user)
    return 0 unless participant
    threshold = participant.last_read_at || Time.at(0)
    messages.where("created_at > ? AND user_id <> ?", threshold, user.id).count
  end
end
