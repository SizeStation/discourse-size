# frozen_string_literal: true

module DiscourseSize
  class InventoryController < ::ApplicationController
    requires_plugin DiscourseSize::PLUGIN_NAME
    before_action :ensure_logged_in

    def index
      user_id = params[:user_id] || current_user.id
      user = User.find(user_id)
      
      # Only self or admin/mod can see inventory
      guardian.ensure_can_edit_user!(user)
      
      inventory = DiscourseSizeInventory.where(user_id: user.id)
      
      render json: { 
        inventory: serialize_data(inventory, DiscourseSizeInventorySerializer),
        current_points: ::DiscourseSize::PointsManager.get_points(user)
      }
    end

    def use
      Rails.logger.info("[DiscourseSize] InventoryController#use params: #{params.inspect}")
      result = ::DiscourseSize::InventoryManager.use_item(current_user, params[:inventory_item_id], params[:character_id])
      
      if result[:success]
        render json: { 
          success: true, 
          character: serialize_data(result[:character], DiscourseSizeCharacterSerializer)
        }
      else
        render json: { failed: true, message: result[:error] }, status: 422
      end
    end
    def gift
      result = ::DiscourseSize::InventoryManager.gift_item(current_user, params[:inventory_item_id], params[:username])
      
      if result[:success]
        render json: success_json
      else
        render json: { failed: true, message: result[:error] }, status: 422
      end
    end
  end
end
