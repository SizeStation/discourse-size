# frozen_string_literal: true

class AddCanOnlyUseOnSelfAndWarningToShopItems < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_size_shop_items, :can_only_use_on_self, :boolean, default: false, null: false
    add_column :discourse_size_shop_items, :warning_text, :text
  end
end
