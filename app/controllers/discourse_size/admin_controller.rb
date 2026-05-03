# frozen_string_literal: true

module DiscourseSize
  class AdminController < ::ApplicationController
    requires_plugin DiscourseSize::PLUGIN_NAME
    before_action :ensure_admin

    def update_character
      character = DiscourseSizeCharacter.find(params[:id])
      
      updates = {}
      updates[:growth_rate_override] = params[:growth_rate_override].to_f if params[:growth_rate_override]
      updates[:base_size] = params[:base_size].to_f if params[:base_size]
      
      if params.has_key?(:current_size)
        # Directly set size
        new_size = params[:current_size].to_f
        # Because current_size = base_size + current_offset
        updates[:current_offset] = new_size - character.base_size
        updates[:target_offset] = updates[:current_offset]
        updates[:offset_updated_at] = Time.now
      end

      if character.update(updates)
        render json: success_json
      else
        render json: failed_json.merge(errors: character.errors.full_messages), status: 422
      end
    end

    def update_points
      user = User.find(params[:user_id])
      amount = params[:points].to_i
      
      DiscourseSize::PointsManager.set_points(user, amount)
      
      render json: success_json
    end
  end
end
