# frozen_string_literal: true

module DiscourseSize
  class AdminController < ::ApplicationController
    requires_plugin DiscourseSize::PLUGIN_NAME

    before_action :ensure_admin

    def update_character
      character = DiscourseSizeCharacter.find(params[:id])

      character.base_size = params[:base_size] if params[:base_size]
      character.growth_rate_override = params[:growth_rate_override]

      if params[:current_size]
        new_size = params[:current_size].to_f
        new_offset = new_size - character.base_size
        character.current_offset = new_offset
        character.target_offset = new_offset
        character.start_offset = new_offset
        character.offset_updated_at = Time.now
      end

      character.save!

      render json: { character: character_serializer(character) }
    end

    def update_points
      user = User.find(params[:user_id])
      new_points = params[:points].to_i

      DiscourseSize::PointsManager.set_points(user, new_points)

      render json: { points: new_points }
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
        allow_growth: c.allow_growth,
        allow_shrink: c.allow_shrink,
        measurement_system: c.measurement_system,
        is_main: c.is_main,
        growth_rate_bought: c.growth_rate_bought,
        is_biggest: false, # simplified for admin view
        is_tiniest: false,
        biggest_rank: biggest_rank,
        tiniest_rank: tiniest_rank,
        growth_rate_override: c.growth_rate_override,
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
                size_change: a.size_change,
                points_spent:
                  (
                    if DiscourseSizeAction.column_names.include?("points_spent")
                      a.points_spent.to_f
                    else
                      0.0
                    end
                  ),
                created_at: a.created_at,
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
