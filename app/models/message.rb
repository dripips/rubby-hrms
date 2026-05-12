class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :user

  validates :body, presence: true, length: { maximum: 5000 }

  after_create_commit :update_conversation_timestamp
  after_create_commit :broadcast_to_conversation

  private

  def update_conversation_timestamp
    conversation.update_column(:last_message_at, created_at)
  end

  # Broadcast прилетит во все открытые вкладки участников.
  # Используем Turbo Stream для лёгкой интеграции с view.
  def broadcast_to_conversation
    broadcast_append_to(
      conversation,
      target:  "conversation_#{conversation_id}_messages",
      partial: "messages/message",
      locals:  { message: self }
    )
  end
end
