# frozen_string_literal: true

module DiscourseSize
  class PointHistoryController < ::ApplicationController
    requires_plugin DiscourseSize::PLUGIN_NAME
    before_action :ensure_logged_in

    def index
      user_id = params[:user_id] || current_user.id
      user = User.find(user_id)
      
      # Only self or admin/mod can see history
      guardian.ensure_can_edit_user!(user)
      
      history = DiscourseSizePointHistory.where(user_id: user.id).order(created_at: :desc).limit(100)
      
      render json: { 
        history: serialize_data(history, DiscourseSizePointHistorySerializer),
        current_points: PointsManager.get_points(user)
      }
    end

    def destroy
      guardian.ensure_admin!
      
      entry = DiscourseSizePointHistory.find(params[:id])
      user = entry.user
      
      # Revert points
      PointsManager.add_points(
        user, 
        -entry.amount, 
        source_type: "admin_correction", 
        description: "Reverted transaction ##{entry.id}"
      )
      
      entry.destroy
      render json: success_json
    end
  end
end
