# frozen_string_literal: true

module DiscourseSize
  class CharactersController < ::ApplicationController
    requires_plugin DiscourseSize::PLUGIN_NAME
    before_action :ensure_logged_in, except: [:index]

    def index
      user_id = params[:user_id]
      folders = DiscourseSizeFolder.where(user_id: user_id).order(position: :asc)
      characters = DiscourseSizeCharacter.where(user_id: user_id).order(is_main: :desc, position: :asc, created_at: :asc)

      # sync offsets before rendering
      characters.each(&:sync_offset!)

      render json: {
        folders: folders.map { |f| folder_serializer(f) },
        characters: serialize_data(characters, ::DiscourseSizeCharacterSerializer)
      }
    end

    def show
      character = DiscourseSizeCharacter.find(params[:id])
      render json: { character: serialize_data(character, DiscourseSizeCharacterSerializer) }
    end

    def reorder
      user_id = params[:user_id] || current_user.id
      guardian.ensure_can_edit_user!(User.find(user_id))

      if params[:character_mapping]
        DiscourseSizeCharacter.reorder(User.find(user_id), params[:character_mapping])
      end

      if params[:folder_id] && params[:character_ids]
        # folder_id can be nil (move out of folder)
        DiscourseSizeCharacter.where(id: params[:character_ids], user_id: user_id).update_all(folder_id: params[:folder_id])
      end

      render json: success_json
    end

    def create
      character =
        DiscourseSizeCharacter.new(
          character_params.merge(user_id: current_user.id, offset_updated_at: Time.now),
        )

      if character.save
        render json: { character: serialize_data(character, DiscourseSizeCharacterSerializer) }
      else
        render json: failed_json.merge(errors: character.errors.full_messages),
               status: :unprocessable_content
      end
    end

    def update
      character = DiscourseSizeCharacter.find(params[:id])
      unless character.user_id == current_user.id || current_user.admin?
        raise Discourse::InvalidAccess
      end

      # character_type cannot be changed after creation
      p = character_params
      p.delete(:character_type)
      
      # Ensure arrays are present even if empty in request
      p[:blocked_item_keys] ||= []
      p[:blocked_user_ids] ||= []

      if character.update(p)
        render json: { character: serialize_data(character, DiscourseSizeCharacterSerializer) }
      else
        render json: failed_json.merge(errors: character.errors.full_messages),
               status: :unprocessable_content
      end
    end

    def destroy
      character = DiscourseSizeCharacter.find(params[:id])
      unless character.user_id == current_user.id || current_user.admin?
        raise Discourse::InvalidAccess
      end

      character.destroy
      render json: success_json
    end

    def reorder_top_level
      user_id = params[:user_id] || current_user.id
      guardian.ensure_can_edit_user!(User.find(user_id))

      mapping = params[:mapping] || []
      mapping = mapping.values if mapping.respond_to?(:values)

      mapping.each_with_index do |item, index|
        if item[:type] == "character"
          DiscourseSizeCharacter.where(id: item[:id], user_id: user_id).update_all(
            position: index,
            folder_id: nil,
          )
        elsif item[:type] == "folder"
          DiscourseSizeFolder.where(id: item[:id], user_id: user_id).update_all(
            position: index,
          )
        end
      end

      render json: success_json
    end

    def set_main
      character = DiscourseSizeCharacter.find(params[:id])
      raise Discourse::InvalidAccess unless character.user_id == current_user.id

      DiscourseSizeCharacter.where(user_id: current_user.id).update_all(is_main: false)
      character.update!(is_main: true)

      render json: success_json
    end

    def unset_main
      character = DiscourseSizeCharacter.find(params[:id])
      raise Discourse::InvalidAccess unless character.user_id == current_user.id

      character.update!(is_main: false)

      render json: success_json
    end

    def set_size
      character = DiscourseSizeCharacter.find(params[:id])
      unless character.freeform? || current_user.admin?
        return render json: failed_json.merge(error: "Only Freeform characters can set size directly"), status: :forbidden
      end

      unless character.user_id == current_user.id || current_user.admin?
        raise Discourse::InvalidAccess
      end

      new_total_cm = params[:size].to_f
      new_total_cm = 1e-18 if new_total_cm < 1e-18
      new_total_cm = DiscourseSizeCharacter::MAX_SIZE if new_total_cm > DiscourseSizeCharacter::MAX_SIZE

      # Stop all pending growth/shrinking
      character.discourse_size_actions.where(action_type: ["grow", "shrink"]).where("end_time > ?", Time.now).destroy_all

      old_target_offset = character.target_offset
      new_offset = new_total_cm - character.base_size
      size_change = new_offset - old_target_offset

      character.current_offset = new_offset
      character.target_offset = new_offset
      character.start_offset = new_offset
      character.offset_updated_at = Time.now
      character.save!

      DiscourseSizeAction.create!(
        character_id: character.id,
        user_id: current_user.id,
        action_type: "set_size",
        size_change: size_change,
        points_spent: 0,
        start_offset: old_target_offset,
        end_offset: new_offset,
        duration_minutes: 0,
        start_time: Time.now,
        end_time: Time.now
      )

      render json: {
               character: serialize_data(character, DiscourseSizeCharacterSerializer),
               points: DiscourseSize::PointsManager.get_points(current_user),
             }
    end

    def destroy_action
      action = DiscourseSizeAction.find(params[:id])
      unless current_user.admin? || action.character.user_id == current_user.id
        raise Discourse::InvalidAccess
      end

      # Cannot delete linked self-effect actions individually
      if action.parent_action_id.present? && !current_user.admin?
        return render json: { failed: true, message: "This activity entry is linked to another character's interaction and cannot be deleted individually." }, status: :unprocessable_content
      end

      # Delete notification if it exists
      if action.respond_to?(:notification_id) && action.notification_id
        DiscourseSize::NotificationManager.delete_notification(action.notification_id)
      end

      character = action.character
      character.sync_offset!

      # Revert points (only for parent actions)
      if action.points_spent > 0 && action.parent_action_id.blank?
        DiscourseSize::PointsManager.add_points(
          action.user,
          action.points_spent,
          source_type: "action_reverted",
          description: "Reverted #{action.action_type} on #{character.name}"
        )
        # Notify user about points return
        DiscourseSize::NotificationManager.send_item_returned_notification(
          action.user,
          "#{action.points_spent} coins",
          character.name
        )
      end

      # Revert item (only for parent actions)
      if action.item_key && action.parent_action_id.blank?
        DiscourseSize::InventoryManager.return_item(action.user, action.item_key)
        # Notify user about item return
        item = DiscourseSizeShopItem.find_by(key: action.item_key)
        DiscourseSize::NotificationManager.send_item_returned_notification(
          action.user,
          item&.name || action.item_key,
          character.name
        )
      end

      case action.action_type
      when "boost_speed"
        character.growth_rate_bought -= action.size_change
      end

      # Handle linked child action state sync
      child = action.child_action
      child_char = child&.character
      
      action.destroy # This will also destroy the child action via dependent: :destroy
      
      # Refresh character states
      character.reload.recalculate_pending_actions!
      child_char.reload.recalculate_pending_actions! if child_char

      render json: {
               character: serialize_data(character.reload, DiscourseSizeCharacterSerializer),
             }
    end

    def block_user
      character = DiscourseSizeCharacter.find(params[:id])
      raise Discourse::InvalidAccess unless character.user_id == current_user.id || current_user.admin?
      
      user_to_block = User.find(params[:user_id])
      
      # Owner cannot block themselves
      if user_to_block.id == character.user_id
        return render json: { character: serialize_data(character, DiscourseSizeCharacterSerializer) }
      end

      character.blocked_user_ids = (character.blocked_user_ids + [user_to_block.id]).uniq
      character.save!
      
      render json: { character: serialize_data(character.reload, DiscourseSizeCharacterSerializer) }
    end

    def unblock_user
      character = DiscourseSizeCharacter.find(params[:id])
      raise Discourse::InvalidAccess unless character.user_id == current_user.id || current_user.admin?
      
      target_id = params[:user_id].to_i
      character.blocked_user_ids = character.blocked_user_ids.map(&:to_i).reject { |id| id == target_id }
      character.save!
      
      render json: { character: serialize_data(character.reload, DiscourseSizeCharacterSerializer) }
    end

    def update_blocked_items
      character = DiscourseSizeCharacter.find(params[:id])
      raise Discourse::InvalidAccess unless character.user_id == current_user.id || current_user.admin?
      
      character.blocked_item_keys = params[:blocked_item_keys] || []
      character.save!
      
      render json: { character: serialize_data(character.reload, DiscourseSizeCharacterSerializer) }
    end

    private

    def character_params
      params.permit(
        :name,
        :picture,
        :info_post,
        :base_size,
        :is_main,
        :character_type,
        :gender,
        :pronouns,
        :age,
        :species,
        :description,
        :show_comparison,
        blocked_item_keys: [],
        blocked_user_ids: []
      )
    end

    def folder_serializer(f)
      {
        id: f.id,
        name: f.name,
        position: f.position,
        user_id: f.user_id,
        hex_color: f.hex_color,
      }
    end
  end
end
