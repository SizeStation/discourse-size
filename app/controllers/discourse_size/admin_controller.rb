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
        character.offset_updated_at = Time.now
      end

      character.save!

      render json: success_json
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
  end
end
