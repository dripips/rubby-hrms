class JobApplicant < ApplicationRecord
  include Discard::Model
  include Auditable
  include AASM

  STAGES = %w[applied screening interview offered hired rejected withdrawn].freeze
  ACTIVE_STAGES   = %w[applied screening interview offered].freeze
  CLOSED_STAGES   = %w[hired rejected withdrawn].freeze

  belongs_to :company
  belongs_to :job_opening, optional: true
  belongs_to :owner, class_name: "User", optional: true

  has_many :stage_changes, class_name: "ApplicationStageChange", dependent: :destroy
  has_many :notes,         class_name: "ApplicantNote",          dependent: :destroy

  has_one_attached  :photo
  has_one_attached  :resume
  has_many_attached :portfolio_files

  has_many :test_assignments,  dependent: :destroy
  has_many :interview_rounds,  dependent: :destroy

  before_validation :set_defaults, on: :create

  validates :first_name, :last_name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :stage, inclusion: { in: STAGES }
  validates :overall_score, numericality: { only_integer: true, in: 0..100, allow_nil: true }

  scope :active,  -> { kept.where(stage: ACTIVE_STAGES) }
  scope :on_stage, ->(stage) { kept.where(stage: stage) }
  scope :recent,  -> { kept.order(applied_at: :desc) }

  # Разрешаем переход между любыми стадиями: recruitment-процесс часто
  # нелинейный (вернули кандидата из отказа, переоткрыли оффер, и т.д.).
  # Все события без `from:` — Pundit + UI решают кто и когда может двигать.
  aasm column: :stage, whiny_persistence: true do
    state :applied, initial: true
    state :screening
    state :interview
    state :offered
    state :hired
    state :rejected
    state :withdrawn

    event :move_to_screening  do transitions to: :screening  end
    event :schedule_interview do transitions to: :interview  end
    event :make_offer         do transitions to: :offered    end
    event :hire               do transitions to: :hired      end
    event :reject             do transitions to: :rejected   end
    event :withdraw           do transitions to: :withdrawn  end
    event :reopen             do transitions to: :applied    end
  end

  def full_name
    [ last_name, first_name ].compact_blank.join(" ")
  end

  def initials
    [ last_name, first_name ].compact.map { |n| n.first&.upcase }.join
  end

  # Возвращает URL фото: либо ActiveStorage attachment, либо external URL
  # из source_meta (например, pravatar для seed). Иначе nil — рендерим инициалы.
  def avatar_url
    return Rails.application.routes.url_helpers.rails_blob_path(photo, only_path: true) if photo.attached?

    source_meta&.dig("avatar_url")
  end

  def days_in_stage
    return 0 unless stage_changed_at

    (Time.current.to_date - stage_changed_at.to_date).to_i
  end

  # Перевод в новую стадию: AASM event + история перехода + обновление timestamp.
  def transition_to!(new_stage, user:, comment: nil)
    event = case new_stage.to_s
    when "screening"  then :move_to_screening
    when "interview"  then :schedule_interview
    when "offered"    then :make_offer
    when "hired"      then :hire
    when "rejected"   then :reject
    when "withdrawn"  then :withdraw
    when "applied"    then :reopen
    end
    return false unless event

    transaction do
      from = stage
      public_send("#{event}!")
      update!(stage_changed_at: Time.current)
      stage_changes.create!(
        from_stage: from,
        to_stage:   new_stage,
        user:       user,
        comment:    comment,
        changed_at: Time.current
      )
    end
    true
  end

  private

  def set_defaults
    self.applied_at        ||= Time.current
    self.stage_changed_at  ||= Time.current
    self.source            ||= "manual"
  end
end
