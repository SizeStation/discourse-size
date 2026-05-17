# frozen_string_literal: true

module ::DiscourseSize
  class NotificationManager
    def self.send_growth_notification(actor, character, action_type, amount_cm, item_name: nil)
      return if !actor || !character || actor.id == character.user_id

      notification_type = Notification.types[:discourse_size_notification] || 2600
      return if Notification.types.values.exclude?(notification_type)

      notification_data = {
        actor_username: actor.username,
        character_name: character.name,
        action_type: action_type, # 'grow' or 'shrink'
        amount_cm: amount_cm.abs,
        measurement_system: DiscourseSizeUserSetting.for_user(character.user).measurement_system,
        item_name: item_name
      }

      notification = Notification.create!(
        notification_type: notification_type,
        user_id: character.user_id,
        data: notification_data.to_json
      )
      
      notification.id
    end

    def self.send_item_returned_notification(user, item_name, character_name)
      notification_type = Notification.types[:discourse_size_notification] || 2600
      return if Notification.types.values.exclude?(notification_type)

      notification_data = {
        item_name: item_name,
        character_name: character_name,
        returned: true
      }

      Notification.create!(
        notification_type: notification_type,
        user_id: user.id,
        data: notification_data.to_json
      )
    end

    def self.send_gift_notification(sender, target_user, item_name)
      notification_type = Notification.types[:discourse_size_notification] || 2600
      return if Notification.types.values.exclude?(notification_type)

      notification_data = {
        actor_username: sender.username,
        item_name: item_name,
        gift_received: true
      }

      Notification.create!(
        notification_type: notification_type,
        user_id: target_user.id,
        data: notification_data.to_json
      )
    end

    def self.send_roleplay_invite(roleplay, character)
      notification_type = Notification.types[:discourse_size_notification] || 2600
      return if Notification.types.values.exclude?(notification_type)

      notification_data = {
        roleplay_name: roleplay.name,
        roleplay_id: roleplay.uuid,
        character_name: character.name,
        invite: true
      }

      Notification.create!(
        notification_type: notification_type,
        user_id: character.user_id,
        data: notification_data.to_json
      )
    end

    def self.delete_notification(notification_id)
      return unless notification_id
      Notification.find_by(id: notification_id)&.destroy
    end
  end
end
