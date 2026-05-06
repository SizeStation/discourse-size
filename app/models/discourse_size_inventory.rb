# frozen_string_literal: true

class DiscourseSizeInventory < ActiveRecord::Base
  self.table_name = "discourse_size_inventory"
  belongs_to :user

  validates :user_id, presence: true
  validates :item_key, presence: true
  validates :uses_remaining, numericality: { greater_than_or_equal_to: 0 }

  def item_details
    DiscourseSizeShopItem.find_by(key: item_key)
  end
end
