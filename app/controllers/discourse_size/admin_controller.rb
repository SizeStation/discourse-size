# frozen_string_literal: true

module DiscourseSize
  class AdminController < ::ApplicationController
    requires_plugin DiscourseSize::PLUGIN_NAME

    before_action :ensure_admin

    def update_character
      character = DiscourseSizeCharacter.find(params[:id])
      character.sync_offset!

      if params[:base_size]
        character.base_size = params[:base_size].to_f
      end

      if params[:current_size]
        new_size = params[:current_size].to_f
        new_offset = new_size - character.base_size
        delta = new_offset - character.current_offset

        character.current_offset = new_offset
        character.target_offset += delta
        character.start_offset += delta
        character.offset_updated_at = Time.now

        # Shift all grow/shrink actions to reflect the jump
        character.discourse_size_actions.where(action_type: ["grow", "shrink"]).each do |action|
          if action.start_offset && action.end_offset
            action.update_columns(
              start_offset: action.start_offset + delta,
              end_offset: action.end_offset + delta
            )
          end
        end
      end

      character.save!

      render json: { character: character_serializer(character) }
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

    private

    def ensure_admin
      raise Discourse::InvalidAccess unless current_user&.admin?
    end

    def character_serializer(c)
      c.sync_offset!

      # Calculate rank (exclude freeform characters)
      if c.game?
        biggest_rank =
          DiscourseSizeCharacter.where(character_type: 'game').where(
            "(base_size + current_offset) > ?",
            c.base_size + c.current_offset,
          ).count + 1
        tiniest_rank =
          DiscourseSizeCharacter.where(character_type: 'game').where(
            "(base_size + current_offset) < ?",
            c.base_size + c.current_offset,
          ).count + 1
      else
        biggest_rank = nil
        tiniest_rank = nil
      end

      {
        id: c.id,
        user_id: c.user_id,
        username: c.user.username,
        name: c.name,
        picture: c.picture,
        info_post: c.info_post,
        base_size: c.base_size,
        current_offset: c.current_offset,
        target_offset: c.target_offset,
        start_offset: c.start_offset,
        offset_updated_at: c.offset_updated_at,
        current_size: c.current_size,
        measurement_system: c.measurement_system,
        is_main: c.is_main,
        is_biggest: false, # simplified for admin view
        is_tiniest: false,
        biggest_rank: biggest_rank,
        tiniest_rank: tiniest_rank,
        character_type: c.character_type,
        gender: c.gender,
        pronouns: c.pronouns,
        age: c.age,
        species: c.species,
        description: c.description,
        show_comparison: c.show_comparison,
        actions:
          c
            .discourse_size_actions
            .order(created_at: :desc)
            .limit(20)
            .map do |a|
              {
                id: a.id,
                action_type: a.action_type,
                created_at: a.created_at,
                duration_minutes: a.duration_minutes,
                start_time: a.start_time,
                end_time: a.end_time,
                size_change: a.size_change,
                points_spent: a.points_spent.to_f,
                start_offset: a.start_offset,
                end_offset: a.end_offset,
                user: {
                  id: a.user.id,
                  username: a.user.username,
                  avatar_template: a.user.avatar_template,
                },
              }
            end,
      }
    end
  end
end
