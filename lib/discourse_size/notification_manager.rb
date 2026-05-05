# frozen_string_literal: true

module DiscourseSize
  class NotificationManager
    def self.send_growth_notification(actor, character, action_type, amount_cm)
      return if actor.id == character.user_id

      # We'll use a custom notification type. 
      # Since we don't have a specific type registered, we'll use 'custom' or just piggyback on another one.
      # But best is to use a consistent data structure for the frontend to interpret.
      
      notification_data = {
        actor_username: actor.username,
        character_name: character.name,
        action_type: action_type, # 'grow' or 'shrink'
        amount_cm: amount_cm.abs,
        measurement_system: character.measurement_system
      }

      notification = Notification.create!(
        notification_type: Notification.types[:discourse_size_notification] || Notification.types[:custom],
        user_id: character.user_id,
        data: notification_data.to_json
      )
      
      notification.id
    end

    def self.delete_notification(notification_id)
      return unless notification_id
      Notification.find_by(id: notification_id)&.destroy
    end
  end
end
