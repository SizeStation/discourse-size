# frozen_string_literal: true

class DiscourseSizeInventorySerializer < ApplicationSerializer
  attributes :id, :user_id, :item_key, :uses_remaining, :created_at
  
  has_one :details, serializer: DiscourseSizeShopItemSerializer, embed: :objects

  def details
    DiscourseSizeShopItem.find_by(key: object.item_key)
  end
end
