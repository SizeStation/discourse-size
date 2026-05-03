# frozen_string_literal: true

module DiscourseSize
  class CharactersController < ::ApplicationController
    requires_plugin DiscourseSize::PLUGIN_NAME
    before_action :ensure_logged_in, except: [:index]

    def index
      user_id = params[:user_id]
      characters = DiscourseSizeCharacter.where(user_id: user_id).order(is_main: :desc, created_at: :asc)
      
      # sync offsets before rendering
      characters.each(&:sync_offset!)
      
      render json: { characters: characters.map { |c| character_serializer(c) } }
    end

    def create
      character = DiscourseSizeCharacter.new(character_params.merge(
        user_id: current_user.id,
        offset_updated_at: Time.now
      ))
      
      if character.save
        render json: { character: character_serializer(character) }
      else
        render json: failed_json.merge(errors: character.errors.full_messages), status: :unprocessable_content
      end
    end

    def update
      character = DiscourseSizeCharacter.find(params[:id])
      raise Discourse::InvalidAccess unless character.user_id == current_user.id || current_user.admin?

      # size is NOT freely editable here, only name, picture, info_post, settings
      if character.update(character_params)
        render json: { character: character_serializer(character) }
      else
        render json: failed_json.merge(errors: character.errors.full_messages), status: :unprocessable_content
      end
    end

    def destroy
      character = DiscourseSizeCharacter.find(params[:id])
      raise Discourse::InvalidAccess unless character.user_id == current_user.id || current_user.admin?
      
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

    def grow
      character = DiscourseSizeCharacter.find(params[:id])
      amount = params[:amount].to_f
      points_cost = amount.abs.ceil # simple 1 point per 1 cm logic? Wait, I didn't get a point ratio. Let's do 1 point per cm for now.
      
      raise Discourse::InvalidAccess unless character.allow_growth || character.user_id == current_user.id || current_user.admin?
      
      points = DiscourseSize::PointsManager.get_points(current_user)
      if points < points_cost
        return render json: failed_json.merge(error: "Not enough points"), status: :unprocessable_content
      end

      DiscourseSize::PointsManager.remove_points(current_user, points_cost)
      character.update_size_target(amount)
      
      DiscourseSizeAction.create!(
        character_id: character.id,
        user_id: current_user.id,
        action_type: 'grow',
        size_change: amount
      )

      render json: { character: character_serializer(character), points: DiscourseSize::PointsManager.get_points(current_user) }
    end

    def shrink
      character = DiscourseSizeCharacter.find(params[:id])
      amount = params[:amount].to_f.abs
      points_cost = amount.ceil
      
      raise Discourse::InvalidAccess unless character.allow_shrink || character.user_id == current_user.id || current_user.admin?
      
      points = DiscourseSize::PointsManager.get_points(current_user)
      if points < points_cost
        return render json: failed_json.merge(error: "Not enough points"), status: :unprocessable_content
      end

      DiscourseSize::PointsManager.remove_points(current_user, points_cost)
      character.update_size_target(-amount)
      
      DiscourseSizeAction.create!(
        character_id: character.id,
        user_id: current_user.id,
        action_type: 'shrink',
        size_change: -amount
      )

      render json: { character: character_serializer(character), points: DiscourseSize::PointsManager.get_points(current_user) }
    end

    def reset_size
      character = DiscourseSizeCharacter.find(params[:id])
      raise Discourse::InvalidAccess unless character.user_id == current_user.id || current_user.admin?
      
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
        action_type: 'reset',
        size_change: 0
      )

      render json: { character: character_serializer(character), points: DiscourseSize::PointsManager.get_points(current_user) }
    end

    private

    def biggest_character_id
      @biggest_character_id ||= DiscourseSizeCharacter.order(Arel.sql("(base_size + current_offset) DESC")).limit(1).pluck(:id).first
    end

    def tiniest_character_id
      @tiniest_character_id ||= DiscourseSizeCharacter.order(Arel.sql("(base_size + current_offset) ASC")).limit(1).pluck(:id).first
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
        :measurement_system
      )
    end

    def character_serializer(c)
      c.sync_offset!
      
      # Calculate rank
      biggest_rank = DiscourseSizeCharacter.where("(base_size + current_offset) > ?", c.base_size + c.current_offset).count + 1
      tiniest_rank = DiscourseSizeCharacter.where("(base_size + current_offset) < ?", c.base_size + c.current_offset).count + 1

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
        actions: c.discourse_size_actions.order(created_at: :desc).limit(20).map do |a|
          {
            id: a.id,
            action_type: a.action_type,
            size_change: a.size_change,
            created_at: a.created_at,
            user: {
              id: a.user.id,
              username: a.user.username,
              avatar_template: a.user.avatar_template
            }
          }
        end
      }
    end
  end
end
