class ConversationsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_conversation, only: %i[show destroy]

  def index
    # Standalone-чаты + context-bound discussions вместе. У context-bound
    # есть target-тег с линком на сущность.
    @conversations = Conversation.for_user(current_user).recent
                                 .includes(:participants, :targetable).limit(100)
  end

  def show
    # Отмечаем диалог прочитанным
    participant = @conversation.conversation_participants.find_by(user: current_user)
    participant&.update_column(:last_read_at, Time.current)
    @messages = @conversation.messages.includes(:user).limit(200)
    @new_message = @conversation.messages.new
  end

  def new
    @recipients = User.kept.where.not(id: current_user.id).order(:email)
  end

  def create
    recipient_ids = Array(params[:recipient_ids]).map(&:to_i).reject(&:zero?)
    recipients    = User.kept.where(id: recipient_ids).to_a
    if recipients.empty?
      redirect_to new_conversation_path,
                  alert: t("chat.errors.no_recipients", default: "Выбери хотя бы одного собеседника") and return
    end

    conversation = Conversation.between(current_user, *recipients)
    if params[:subject].present?
      conversation.update(subject: params[:subject].to_s.strip[0, 200])
    end
    redirect_to conversation_path(conversation)
  end

  def destroy
    @conversation.destroy if @conversation.creator_id == current_user.id
    redirect_to conversations_path
  end

  private

  def load_conversation
    @conversation = Conversation.for_user(current_user).find(params[:id])
  end
end
