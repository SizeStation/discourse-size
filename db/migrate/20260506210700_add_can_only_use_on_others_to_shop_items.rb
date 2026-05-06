# frozen_string_literal: true

class AddCanOnlyUseOnOthersToShopItems < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_size_shop_items, :can_only_use_on_others, :boolean, default: false, null: false
  end
end
