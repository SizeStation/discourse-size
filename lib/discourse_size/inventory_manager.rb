# frozen_string_literal: true

module ::DiscourseSize
  class InventoryManager
    def self.purchase(user, item_key)
      item = DiscourseSizeShopItem.find_by(key: item_key)

      return { error: "Item not found" } unless item
      return { error: "Item is disabled" } unless item.enabled
      return { error: "Item is out of stock" } unless item.in_stock?

      price = item.price.to_i
      return { error: "Insufficient points" } if PointsManager.get_points(user) < price

      # Deduct points
      PointsManager.remove_points(
        user,
        price,
        source_type: "purchase_item",
        description: "Purchased #{item.name}"
      )

      # Add to inventory
      inventory_item = DiscourseSizeInventory.create!(
        user_id: user.id,
        item_key: item_key,
        uses_remaining: item.uses.to_i > 0 ? item.uses.to_i : 999999 # Use large number for infinite
      )

      { success: true, inventory_item: inventory_item }
    end

    def self.use_item(user, inventory_item_id, target_character_id)
      Rails.logger.info("[DiscourseSize] Using item: user_id=#{user.id}, inventory_item_id=#{inventory_item_id}, target_character_id=#{target_character_id}")

      inventory_item = DiscourseSizeInventory.find_by(id: inventory_item_id, user_id: user.id)

      unless inventory_item
        all_ids = DiscourseSizeInventory.where(user_id: user.id).pluck(:id)
        Rails.logger.info("[DiscourseSize] Item not found in inventory for user #{user.id}. Looking for ID #{inventory_item_id}. User actually has IDs: #{all_ids.inspect}")
        return { error: "Item not in inventory" }
      end

      return { error: "No uses remaining" } if inventory_item.uses_remaining <= 0

      character = DiscourseSizeCharacter.find(target_character_id)
      item = inventory_item.item_details
      return { error: "Item configuration missing (it may have been deleted)" } unless item

      # Check if blocked
      if character.is_blocked?(user, item_key: inventory_item.item_key)
        return { error: "This character has blocked this item or you from performing actions." }
      end

      # Apply effect
      # Sequential stacking logic
      start_offset = character.target_offset
      current_target_total = character.base_size + start_offset
      new_target_total = current_target_total * (1.0 + (item.effect == "shrink" ? -item.amount.to_f : item.amount.to_f) / 100.0)
      size_change = new_target_total - current_target_total

      # Track quest activity (only if targeting someone else)
      if character.user_id != user.id
        quest_type = item.effect == "grow" ? :character_grow : :character_shrink
        ::DiscourseSize::QuestManager.track_activity(user, quest_type)
      end

      # Handle self-effect validation first
      main_char = nil
      if item.self_effect.present? && item.self_amount.to_f > 0 && character.user_id != user.id
        main_char = DiscourseSizeCharacter.find_by(user_id: user.id, is_main: true)
        if main_char.nil?
          return { error: "You must set a Main Character to use items with a self-effect." }
        end
      end

      character.add_queued_action(
        action_type: item.effect,
        size_change: size_change,
        duration_minutes: item.duration_minutes.to_f,
        user_id: user.id,
        item_key: item.key
      )

      # Send notification
      notification_id = NotificationManager.send_growth_notification(
        user,
        character,
        item.effect,
        size_change,
        item_name: item.name
      )

      # Find the action we just created to attach notification_id (it will be the last one)
      action = character.discourse_size_actions.where(item_key: item.key, user_id: user.id).order(created_at: :desc).first
      action.update_column(:notification_id, notification_id) if notification_id && action

      # Apply self-effect if configured and applicable
      if main_char
        self_start_offset = main_char.target_offset
        self_current_total = main_char.base_size + self_start_offset
        self_new_total = self_current_total * (1.0 + (item.self_effect == "shrink" ? -item.self_amount.to_f : item.self_amount.to_f) / 100.0)
        self_size_change = self_new_total - self_current_total

        main_char.add_queued_action(
          action_type: item.self_effect,
          size_change: self_size_change,
          duration_minutes: item.duration_minutes.to_f,
          user_id: user.id,
          item_key: item.key,
          parent_action_id: action&.id
        )
      end

      # Duplicate effect to site sinks
      DiscourseSizeCharacter.where(site_sink: true).find_each do |sink_char|
        next if sink_char.id == target_character_id # Already applied if it was the target
        next if sink_char.is_blocked?(user, item_key: inventory_item.item_key, action_type: item.effect)

        # Duplicate effect
        sink_start_offset = sink_char.target_offset
        sink_current_total = sink_char.base_size + sink_start_offset
        sink_new_total = sink_current_total * (1.0 + (item.effect == "shrink" ? -item.amount.to_f : item.amount.to_f) / 100.0)
        sink_size_change = sink_new_total - sink_current_total

        sink_char.add_queued_action(
          action_type: item.effect,
          size_change: sink_size_change,
          duration_minutes: item.duration_minutes.to_f,
          user_id: sink_char.user_id,
          item_key: item.key
        )
      end

      # Decrease uses
      if inventory_item.uses_remaining < 999999
        inventory_item.uses_remaining -= 1
        if inventory_item.uses_remaining <= 0
          inventory_item.destroy
        else
          inventory_item.save!
        end
      end

      { success: true, character: character }
    end
    def self.return_item(user, item_key)
      item_def = DiscourseSizeShopItem.find_by(key: item_key)
      # Items with uses <= 0 are treated as 1-use for return logic unless they are infinite
      max_uses = (item_def && item_def.uses.to_i > 0) ? item_def.uses.to_i : 1

      # Try to stack only if the item supports multiple uses
      if max_uses > 1
        inventory_item = DiscourseSizeInventory.where(user_id: user.id, item_key: item_key)
                                                .where("uses_remaining < ?", max_uses)
                                                .order(uses_remaining: :desc)
                                                .first
        if inventory_item
          inventory_item.uses_remaining += 1
          inventory_item.save!
          return
        end
      end

      # Default: create a new inventory entry with 1 use
      DiscourseSizeInventory.create!(
        user_id: user.id,
        item_key: item_key,
        uses_remaining: 1
      )
    end

    def self.gift_item(sender, inventory_item_id, target_username)
      target_user = User.find_by_username(target_username)
      return { error: "User not found" } unless target_user

      inventory_item = DiscourseSizeInventory.find_by(id: inventory_item_id, user_id: sender.id)
      return { error: "Item not in inventory" } unless inventory_item

      item_name = inventory_item.item_details&.name || "an item"

      # Transfer ownership
      inventory_item.update!(user_id: target_user.id)

      # Send notification
      NotificationManager.send_gift_notification(sender, target_user, item_name)

      { success: true }
    end
  end
end
