# frozen_string_literal: true

module DiscourseSize
  class ShopController < ::ApplicationController
    requires_plugin DiscourseSize::PLUGIN_NAME
    before_action :ensure_admin, only: [:create, :update, :destroy]

    def index
      items = DiscourseSizeShopItem.all
      items = items.enabled unless current_user&.admin?

      respond_to do |format|
        format.html { render "default/empty" }
        format.json do
          render json: {
            items: serialize_data(items, DiscourseSizeShopItemSerializer),
            shop_name: SiteSetting.discourse_size_shop_name,
            current_points: current_user ? PointsManager.get_points(current_user) : 0,
          }
        end
      end
    end

    def create
      item = DiscourseSizeShopItem.create!(shop_item_params)
      render_serialized(item, DiscourseSizeShopItemSerializer)
    end

    def update
      item = DiscourseSizeShopItem.find(params[:id])
      item.update!(shop_item_params)
      render_serialized(item, DiscourseSizeShopItemSerializer)
    end

    def destroy
      item = DiscourseSizeShopItem.find(params[:id])
      # Remove from all inventories
      DiscourseSizeInventory.where(item_key: item.key).destroy_all
      item.destroy!
      render json: success_json
    end

    def purchase
      item_key = params[:item_key]
      item = DiscourseSizeShopItem.enabled.find_by(key: item_key)
      
      if !item || !item.in_stock?
        return render json: { failed: true, message: "Item is out of stock or disabled." }, status: :unprocessable_content
      end

      result = ::DiscourseSize::InventoryManager.purchase(current_user, item_key)
      
      if result[:success]
        item.decrement_stock!
        item.increment_purchase_count!
        render json: { 
          success: true, 
          inventory_item: serialize_data(result[:inventory_item], DiscourseSizeInventorySerializer),
          current_points: ::DiscourseSize::PointsManager.get_points(current_user)
        }
      else
        render json: { failed: true, message: result[:error] }, status: :unprocessable_content
      end
    end

    def claim_reward
      last_reward_date = current_user.custom_fields["discourse_size_last_daily_reward_date"]
      today = Date.today.to_s
      
      if last_reward_date == today
        return render json: { failed: true, message: "Reward already collected today." }, status: :unprocessable_content
      end

      amount = SiteSetting.discourse_size_daily_reward_amount
      current_user.custom_fields["discourse_size_last_daily_reward_date"] = today
      current_user.save_custom_fields(true)
      
      ::DiscourseSize::PointsManager.add_points(
        current_user,
        amount,
        source_type: "daily_reward",
        description: "Daily reward collection"
      )

      render json: { 
        success: true, 
        amount: amount,
        current_points: ::DiscourseSize::PointsManager.get_points(current_user)
      }
    end


    def reorder
      params[:ids].each_with_index do |id, index|
        DiscourseSizeShopItem.where(id: id).update_all(position: index)
      end
      render json: success_json
    end

    def save_settings
      settings = DiscourseSizeUserSetting.for_user(current_user)
      settings.update!(
        measurement_system: params[:measurement_system]
      )
      render json: success_json
    end

    private

    def shop_item_params
      params.permit(:key, :name, :description, :price, :effect, :amount, :duration_minutes, :uses, :picture, :stock, :enabled, :item_type, :color, :self_effect, :self_amount, :can_only_use_on_others)
    end
  end
end
