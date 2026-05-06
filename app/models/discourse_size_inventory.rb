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

# == Schema Information
#
# Table name: discourse_size_inventory
#
#  id             :bigint           not null, primary key
#  item_key       :string           not null
#  uses_remaining :integer          default(0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  user_id        :integer          not null
#
# Indexes
#
#  index_discourse_size_inventory_on_user_id               (user_id)
#  index_discourse_size_inventory_on_user_id_and_item_key  (user_id,item_key)
#
