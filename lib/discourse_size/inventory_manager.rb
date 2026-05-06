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
      # Stacking logic
      character.sync_offset!
      
      last_action = character.discourse_size_actions.where(action_type: ["grow", "shrink"]).where.not(end_time: nil).order(end_time: :desc).first
      start_time = [Time.now, last_action&.end_time].compact.max
      duration = item.duration_minutes.minutes
      end_time = start_time + duration
      
      start_offset = character.target_offset
      current_target_total = character.base_size + start_offset
      new_target_total = current_target_total * (1.0 + (item.effect == "shrink" ? -item.amount.to_f : item.amount.to_f) / 100.0)
      size_change = new_target_total - current_target_total
      new_target = start_offset + size_change
      
      # Clamp to min size
      if character.base_size + new_target < SiteSetting.discourse_size_min_base_size
        new_target = SiteSetting.discourse_size_min_base_size - character.base_size
      end
      
      character.target_offset = new_target
      character.save!
      
      # Record action
      action = DiscourseSizeAction.create!(
        character_id: character.id,
        user_id: user.id,
        action_type: item.effect,
        size_change: size_change,
        points_spent: 0, # Items are pre-purchased
        item_key: item.key,
        start_offset: start_offset,
        end_offset: new_target,
        duration_minutes: item.duration_minutes,
        start_time: start_time,
        end_time: end_time
      )

      # Send notification
      notification_id = NotificationManager.send_growth_notification(
        user,
        character,
        item.effect,
        size_change,
        item_name: item.name
      )
      
      action.update_column(:notification_id, notification_id) if notification_id
      
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
      
      # Transfer ownership
      inventory_item.update!(user_id: target_user.id)
      
      { success: true }
    end
  end
end
