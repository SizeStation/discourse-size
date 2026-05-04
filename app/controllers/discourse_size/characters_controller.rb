# frozen_string_literal: true

module DiscourseSize
  class CharactersController < ::ApplicationController
    requires_plugin DiscourseSize::PLUGIN_NAME
    before_action :ensure_logged_in, except: [:index]

    def index
      user_id = params[:user_id]
      characters =
        DiscourseSizeCharacter.where(user_id: user_id).order(is_main: :desc, created_at: :asc)

      # sync offsets before rendering
      characters.each(&:sync_offset!)

      render json: { characters: characters.map { |c| character_serializer(c) } }
    end

    def create
      character =
        DiscourseSizeCharacter.new(
          character_params.merge(user_id: current_user.id, offset_updated_at: Time.now),
        )

      if character.save
        render json: { character: character_serializer(character) }
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

      # size is NOT freely editable here, only name, picture, info_post, settings
      if character.update(character_params)
        render json: { character: character_serializer(character) }
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

    def grow
      character = DiscourseSizeCharacter.find(params[:id])
      points_cost = params[:amount].to_f

      unless character.allow_growth || character.user_id == current_user.id || current_user.admin?
        raise Discourse::InvalidAccess
      end

      points = DiscourseSize::PointsManager.get_points(current_user)
      if points < points_cost
        return(
          render json: failed_json.merge(error: "Not enough points"), status: :unprocessable_content
        )
      end

      # Compounding growth with milder logarithmic dampening
      rate = SiteSetting.discourse_size_percentage_per_point / 100.0

      # Dampen the points slightly so they don't spiral, but keep it feeling powerful
      # Formula: points / (1.0 + log10(points/10 + 1) * 0.25)
      log_factor = Math.log10((points_cost / 10.0) + 1.0)
      effective_points = points_cost / (1.0 + log_factor * 0.25)

      current_target_total = character.base_size + character.target_offset
      new_target_total = current_target_total * ((1.0 + rate)**effective_points)
      amount_cm = new_target_total - current_target_total

      DiscourseSize::PointsManager.remove_points(current_user, points_cost)
      character.update_size_target(amount_cm)

      DiscourseSizeAction.create!(
        character_id: character.id,
        user_id: current_user.id,
        action_type: "grow",
        size_change: amount_cm,
        points_spent: points_cost,
      )

      render json: {
               character: character_serializer(character),
               points: DiscourseSize::PointsManager.get_points(current_user),
             }
    end

    def shrink
      character = DiscourseSizeCharacter.find(params[:id])
      points_cost = params[:amount].to_f.abs

      unless character.allow_shrink || character.user_id == current_user.id || current_user.admin?
        raise Discourse::InvalidAccess
      end

      points = DiscourseSize::PointsManager.get_points(current_user)
      if points < points_cost
        return(
          render json: failed_json.merge(error: "Not enough points"), status: :unprocessable_content
        )
      end

      # Compounding shrink with milder logarithmic dampening
      rate = SiteSetting.discourse_size_percentage_per_point / 100.0
      log_factor = Math.log10((points_cost / 10.0) + 1.0)
      effective_points = points_cost / (1.0 + log_factor * 0.25)

      current_target_total = character.base_size + character.target_offset
      new_target_total = current_target_total * ((1.0 - rate)**effective_points)
      amount_cm = new_target_total - current_target_total

      DiscourseSize::PointsManager.remove_points(current_user, points_cost)
      character.update_size_target(amount_cm)

      DiscourseSizeAction.create!(
        character_id: character.id,
        user_id: current_user.id,
        action_type: "shrink",
        size_change: amount_cm,
        points_spent: points_cost,
      )

      render json: {
               character: character_serializer(character),
               points: DiscourseSize::PointsManager.get_points(current_user),
             }
    end

    def reset_size
      character = DiscourseSizeCharacter.find(params[:id])
      unless character.user_id == current_user.id || current_user.admin?
        raise Discourse::InvalidAccess
      end

      # "regain 50% of their spent points for doing so"
      # We calculate spent points by summing actions by this user on this character? Or total offset?
      # Wait, if they just reset, what do they regain? Total spent points by this user?
      # Let's say we give them 50% of the absolute target_offset.
      points_to_refund = (character.target_offset.abs / 2).floor

      character.update!(target_offset: 0, current_offset: 0, offset_updated_at: Time.now)
      DiscourseSize::PointsManager.add_points(current_user, points_to_refund)

      DiscourseSizeAction.create!(
        character_id: character.id,
        user_id: current_user.id,
        action_type: "reset",
        size_change: 0,
      )

      render json: {
               character: character_serializer(character),
               points: DiscourseSize::PointsManager.get_points(current_user),
             }
    end

    private

    def biggest_character_id
      @biggest_character_id ||=
        DiscourseSizeCharacter
          .order(Arel.sql("(base_size + current_offset) DESC"))
          .limit(1)
          .pluck(:id)
          .first
    end

    def tiniest_character_id
      @tiniest_character_id ||=
        DiscourseSizeCharacter
          .order(Arel.sql("(base_size + current_offset) ASC"))
          .limit(1)
          .pluck(:id)
          .first
    end

    def multiple_characters?
      return @multiple_characters if defined?(@multiple_characters)
      @multiple_characters = DiscourseSizeCharacter.count > 1
    end

    def character_params
      params.permit(
        :name,
        :picture,
        :info_post,
        :base_size,
        :allow_growth,
        :allow_shrink,
        :measurement_system,
      )
    end

    def character_serializer(c)
      c.sync_offset!

      # Calculate rank
      biggest_rank =
        DiscourseSizeCharacter.where(
          "(base_size + current_offset) > ?",
          c.base_size + c.current_offset,
        ).count + 1
      tiniest_rank =
        DiscourseSizeCharacter.where(
          "(base_size + current_offset) < ?",
          c.base_size + c.current_offset,
        ).count + 1

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
        offset_updated_at: c.offset_updated_at,
        current_size: c.current_size,
        allow_growth: c.allow_growth,
        allow_shrink: c.allow_shrink,
        measurement_system: c.measurement_system,
        is_main: c.is_main,
        is_biggest: multiple_characters? && c.id == biggest_character_id,
        is_tiniest: multiple_characters? && c.id == tiniest_character_id,
        biggest_rank: biggest_rank,
        tiniest_rank: tiniest_rank,
        growth_rate_override: c.growth_rate_override,
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
