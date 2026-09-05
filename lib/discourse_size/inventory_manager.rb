# frozen_string_literal: true

module ::DiscourseSize
  class InventoryManager
    def self.purchase(user, item_key, guardian: nil)
      item = DiscourseSizeShopItem.find_by(key: item_key)

      return { error: "Item not found" } unless item

      can_manage =
        (
          if guardian
            guardian.can_manage_size_shop?
          else
            (user && Guardian.new(user).can_manage_size_shop?)
          end
        )
      return { error: "Item is disabled" } unless item.enabled || can_manage
      return { error: "Item is out of stock" } unless item.in_stock?

      price = item.price.to_i
      return { error: "Insufficient points" } if PointsManager.get_points(user) < price

      inventory_item = nil
      ActiveRecord::Base.transaction do
        # Deduct points
        PointsManager.remove_points(
          user,
          price,
          source_type: "purchase_item",
          description: "Purchased #{item.name}",
        )

        # Add to inventory
        inventory_item =
          DiscourseSizeInventory.create!(
            user_id: user.id,
            item_key: item_key,
            uses_remaining: item.uses.to_i > 0 ? item.uses.to_i : 999_999, # Use large number for infinite
          )
      end

      { success: true, inventory_item: inventory_item }
    end

    def self.use_item(user, inventory_item_id, target_character_id)
      Rails.logger.info(
        "[DiscourseSize] Using item: user_id=#{user&.id}, inventory_item_id=#{inventory_item_id}, target_character_id=#{target_character_id}",
      )

      return { error: "Item not in inventory" } if user.nil? || inventory_item_id.blank?

      DistributedMutex.synchronize("discourse_size_use_item_#{inventory_item_id}") do
        inventory_item = DiscourseSizeInventory.find_by(id: inventory_item_id, user_id: user.id)

        unless inventory_item
          all_ids = DiscourseSizeInventory.where(user_id: user.id).pluck(:id)
          Rails.logger.info(
            "[DiscourseSize] Item not found in inventory for user #{user.id}. Looking for ID #{inventory_item_id}. User actually has IDs: #{all_ids.inspect}",
          )
          return { error: "Item not in inventory" }
        end

        return { error: "No uses remaining" } if inventory_item.uses_remaining <= 0

        character = DiscourseSizeCharacter.find_by(id: target_character_id)
        return { error: "Character not found" } unless character

        item = inventory_item.item_details
        return { error: "Item configuration missing (it may have been deleted)" } unless item

        # Check if blocked
        if character.is_blocked?(
             user,
             item_key: inventory_item.item_key,
             action_type: item.effect,
             amount: item.amount,
           )
          return { error: "This character has blocked this item or you from performing actions." }
        end

        if item.can_only_use_on_others && character.user_id == user.id
          return { error: "This item can only be used on other users' characters." }
        end

        if item.can_only_use_on_self && character.user_id != user.id
          return { error: "This item can only be used on your own characters." }
        end

        # Apply effect
        # Sequential stacking logic
        start_offset = character.target_offset
        current_target_total = character.base_size + start_offset
        if item.effect == "static"
          new_target_total = item.amount.to_f
        elsif item.effect == "shrink"
          new_target_total = current_target_total * (1.0 - item.amount.to_f / 100.0)
        else
          new_target_total = current_target_total * (1.0 + item.amount.to_f / 100.0)
        end
        size_change = new_target_total - current_target_total

        # Track quest activity (only if targeting someone else)
        if character.user_id != user.id
          quest_type =
            if item.effect == "grow"
              :character_grow
            elsif item.effect == "shrink"
              :character_shrink
            elsif size_change > 0
              :character_grow
            elsif size_change < 0
              :character_shrink
            end
          ::DiscourseSize::QuestManager.track_activity(user, quest_type) if quest_type
        end

        # Handle self-effect validation first
        main_char = nil
        if item.self_effect.present? && item.self_amount.to_f > 0 && character.user_id != user.id
          main_char = DiscourseSizeCharacter.find_by(user_id: user.id, is_main: true)
          if main_char.nil?
            return { error: "You must set a Main Character to use items with a self-effect." }
          end
        end

        capped_type = nil
        action_result =
          character.add_queued_action(
            action_type: item.effect == "static" ? "set_size" : item.effect,
            size_change: size_change,
            duration_minutes: item.duration_minutes.to_f,
            user_id: user.id,
            item_key: item.key,
          )
        capped_type = action_result[:capped] if action_result[:capped]

        # Send notification
        notification_id =
          NotificationManager.send_growth_notification(
            user,
            character,
            item.effect,
            item.effect == "static" ? item.amount.to_f : action_result[:size_change],
            item_name: item.name,
          )

        # Find the action we just created to attach notification_id (it will be the last one)
        action =
          character
            .discourse_size_actions
            .where(item_key: item.key, user_id: user.id)
            .order(created_at: :desc)
            .first
        action.update_column(:notification_id, notification_id) if notification_id && action

        # Apply self-effect if configured and applicable (only for game type main characters)
        if main_char&.game?
          self_start_offset = main_char.target_offset
          self_current_total = main_char.base_size + self_start_offset
          if item.self_effect == "static"
            self_new_total = item.self_amount.to_f
          elsif item.self_effect == "shrink"
            self_new_total = self_current_total * (1.0 - item.self_amount.to_f / 100.0)
          else
            self_new_total = self_current_total * (1.0 + item.self_amount.to_f / 100.0)
          end
          self_size_change = self_new_total - self_current_total

          self_action_result =
            main_char.add_queued_action(
              action_type: item.self_effect == "static" ? "set_size" : item.self_effect,
              size_change: self_size_change,
              duration_minutes: item.duration_minutes.to_f,
              user_id: user.id,
              item_key: item.key,
              parent_action_id: action&.id,
            )
          capped_type = self_action_result[:capped] if self_action_result[:capped] && !capped_type
        end

        # Decrease uses
        if inventory_item.uses_remaining < 999_999
          inventory_item.uses_remaining -= 1
          if inventory_item.uses_remaining <= 0
            inventory_item.destroy
          else
            inventory_item.save!
          end
        end

        { success: true, character: character, capped_type: capped_type }
      end
    end

    def self.return_item(user, item_key)
      item_def = DiscourseSizeShopItem.find_by(key: item_key)
      # Items with uses <= 0 are treated as 1-use for return logic unless they are infinite
      max_uses = (item_def && item_def.uses.to_i > 0) ? item_def.uses.to_i : 1

      # Try to stack only if the item supports multiple uses
      if max_uses > 1
        inventory_item =
          DiscourseSizeInventory
            .where(user_id: user.id, item_key: item_key)
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
      DiscourseSizeInventory.create!(user_id: user.id, item_key: item_key, uses_remaining: 1)
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
