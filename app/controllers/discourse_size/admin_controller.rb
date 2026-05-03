# frozen_string_literal: true

module DiscourseSize
  class AdminController < ::ApplicationController
    requires_plugin DiscourseSize::PLUGIN_NAME

    before_action :ensure_admin

    def update_character
      character = DiscourseSizeCharacter.find(params[:id])
      
      character.update!(
        base_size: params[:base_size],
        growth_rate_override: params[:growth_rate_override],
      )
      
      # If admin explicitly changed growth rate, we sync the offset to ensure it's not "jumpy"
      character.sync_offset!
      
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
