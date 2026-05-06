# frozen_string_literal: true

class UpdateShopItemsFeatures < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_size_shop_items, :position, :integer, default: 0, null: false
    add_column :discourse_size_shop_items, :item_type, :string, default: "item", null: false
    add_column :discourse_size_shop_items, :color, :string
    add_column :discourse_size_shop_items, :purchase_count, :integer, default: 0, null: false
    add_column :discourse_size_shop_items, :self_effect, :string
    add_column :discourse_size_shop_items, :self_amount, :float

    add_index :discourse_size_shop_items, :position
  end
end
