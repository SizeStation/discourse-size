# frozen_string_literal: true

class DiscourseSizeShopItemSerializer < ApplicationSerializer
  attributes :id,
             :key,
             :name,
             :description,
             :price,
             :effect,
             :amount,
             :duration_minutes,
             :uses,
             :picture,
             :stock,
             :enabled,
             :owned_count

  def owned_count
    return 0 unless scope&.user
    DiscourseSizeInventory.where(user_id: scope.user.id, item_key: object.key).count
  end
end
