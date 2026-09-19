# frozen_string_literal: true

module DiscourseSize
  class AdminController < ::ApplicationController
    requires_plugin DiscourseSize::PLUGIN_NAME

    before_action :ensure_admin

    def update_character
      character = DiscourseSizeCharacter.find(params[:id])
      character.with_lock do
        character.update!(base_size: params[:base_size].to_f) if params[:base_size]

        if params[:current_size]
          start_size = character.current_size
          end_size =
            params[:current_size].to_f.clamp(
              DiscourseSizeCharacter::MIN_SIZE,
              DiscourseSizeCharacter::MAX_SIZE,
            )

          character
            .discourse_size_actions
            .where(action_type: %w[grow shrink set_size])
            .where("end_time > ?", Time.now)
            .destroy_all

          DiscourseSizeAction.create!(
            character_id: character.id,
            user_id: current_user.id,
            action_type: end_size > start_size ? "grow" : "shrink",
            effect_type: "static",
            effect_amount: end_size,
            size_change: end_size - start_size,
            points_spent: 0,
            start_size: start_size,
            end_size: end_size,
            start_offset: start_size - character.base_size,
            end_offset: end_size - character.base_size,
            start_time: Time.now,
            end_time: Time.now,
            duration_minutes: 0,
          )

          new_offset = end_size - character.base_size
          character.update!(
            current_offset: new_offset,
            target_offset: new_offset,
            start_offset: new_offset,
            offset_updated_at: Time.now,
          )
        else
          character.sync_offset!
        end
      end

      render json: { character: serialize_data(character, ::DiscourseSizeCharacterSerializer) }
    end

    def sync_character
      character = DiscourseSizeCharacter.find(params[:id])

      character.with_lock do
        character.rebuild_offset_chain!
        final_size = character.target_size

        character
          .discourse_size_actions
          .where(action_type: %w[grow shrink set_size])
          .where("end_time > ?", Time.now)
          .update_all(end_time: Time.now, start_time: Time.now)

        final_offset = final_size - character.base_size
        character.update!(
          current_offset: final_offset,
          target_offset: final_offset,
          start_offset: final_offset,
          offset_updated_at: Time.now,
        )
      end

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

      inventory_item =
        DiscourseSizeInventory.create!(
          user_id: user.id,
          item_key: item.key,
          uses_remaining: item.uses,
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

    def mass_update_points
      amount = params[:amount].to_i
      raise Discourse::InvalidParameters.new("Amount must not be zero") if amount == 0

      description = params[:description].presence || "Mass admin distribution"
      source_type = amount > 0 ? "admin_mass_add" : "admin_mass_remove"

      User.human_users.find_each do |user|
        if amount > 0
          DiscourseSize::PointsManager.add_points(
            user,
            amount,
            source_type: source_type,
            description: description,
          )
        else
          DiscourseSize::PointsManager.remove_points(
            user,
            amount.abs,
            source_type: source_type,
            description: description,
          )
        end
      end

      render json: success_json
    end

    def reset_quests
      QuestManager.reset_quests(current_user)
      render json: success_json
    end

    private

    def ensure_admin
      raise Discourse::InvalidAccess unless current_user&.admin?
    end
  end
end
