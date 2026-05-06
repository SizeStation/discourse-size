# frozen_string_literal: true

module DiscourseSize
  class AdminController < ::ApplicationController
    requires_plugin DiscourseSize::PLUGIN_NAME

    before_action :ensure_admin

    def update_character
      character = DiscourseSizeCharacter.find(params[:id])
      character.sync_offset!
      
      old_target_size = character.base_size + character.target_offset

      if params[:base_size]
        character.base_size = params[:base_size].to_f
      end

      if params[:current_size]
        new_size = params[:current_size].to_f
        
        # Stop all pending growth/shrinking (anything ending in the future)
        character.discourse_size_actions.where(action_type: ["grow", "shrink"]).where("end_time > ?", Time.now).destroy_all
        
        # Calculate teleport delta
        new_offset = new_size - character.base_size
        
        # Log the action before changing state so we can calculate delta correctly
        action_type = new_size > old_target_size ? "grow" : "shrink"
        size_change = new_size - old_target_size

        character.current_offset = new_offset
        character.target_offset = new_offset
        character.start_offset = new_offset
        character.offset_updated_at = Time.now
        
        DiscourseSizeAction.create!(
          character_id: character.id,
          user_id: current_user.id,
          action_type: action_type,
          size_change: size_change,
          points_spent: 0,
          start_offset: new_offset - size_change,
          end_offset: new_offset,
          start_time: Time.now,
          end_time: Time.now,
          duration_minutes: 0
        )
      end

      character.save!

      render json: { character: serialize_data(character, ::DiscourseSizeCharacterSerializer) }
    end

    def update_points
      user = User.find(params[:user_id])
      new_points = params[:points].to_i
      description = params[:description] || "Admin manual adjustment"

      DiscourseSize::PointsManager.set_points(user, new_points, description: description)

      render json: { points: new_points }
    end

    def user_inventory
      user = User.find(params[:user_id])
      inventory = DiscourseSizeInventory.where(user_id: user.id).order(created_at: :desc)
      render json: { inventory: serialize_data(inventory, DiscourseSizeInventorySerializer) }
    end

    def user_point_history
      user = User.find(params[:user_id])
      history = DiscourseSizePointHistory.where(user_id: user.id).order(created_at: :desc)
      render json: { history: serialize_data(history, DiscourseSizePointHistorySerializer) }
    end

    def add_inventory_item
      user = User.find_by(id: params[:user_id])
      raise Discourse::NotFound unless user

      item_key = params[:item_key]
      item = DiscourseSizeShopItem.find_by(key: item_key)
      item ||= DiscourseSizeShopItem.find_by(id: item_key) if item_key.to_i > 0
      
      raise Discourse::NotFound unless item

      inventory_item = DiscourseSizeInventory.create!(
        user_id: user.id,
        item_key: item.key,
        uses_remaining: item.uses
      )

      render_serialized(inventory_item, DiscourseSizeInventorySerializer)
    end

    def remove_inventory_item
      inventory_item = DiscourseSizeInventory.find(params[:id])
      inventory_item.destroy!
      render json: success_json
    end

    def clear_daily_reward
      user = User.find(params[:user_id])
      user.custom_fields["discourse_size_last_daily_reward_date"] = nil
      user.save_custom_fields(true)
      render json: success_json
    end

    private

    def ensure_admin
      raise Discourse::InvalidAccess unless current_user&.admin?
    end
  end
end
