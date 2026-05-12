class MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :load_conversation

  def create
    @message = @conversation.messages.new(user: current_user, body: params.dig(:message, :body).to_s.strip)
    if @message.body.blank? || !@message.save
      respond_to do |format|
        format.html { redirect_to conversation_path(@conversation), alert: "Empty message" }
        format.turbo_stream { head :unprocessable_content }
      end
      return
    end

    respond_to do |format|
      format.html { redirect_to conversation_path(@conversation) }
      # Turbo Stream вернёт пустой composer; broadcast уже разослал сообщение
      # всем подключённым вкладкам (включая отправителя).
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("composer", partial: "conversations/composer",
                                                              locals: { conversation: @conversation })
      end
    end
  end

  private

  def load_conversation
    @conversation = Conversation.for_user(current_user).find(params[:conversation_id])
  end
end
