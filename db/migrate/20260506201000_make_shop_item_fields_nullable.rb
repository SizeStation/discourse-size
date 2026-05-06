# frozen_string_literal: true

class MakeShopItemFieldsNullable < ActiveRecord::Migration[7.0]
  def change
    change_column_null :discourse_size_shop_items, :effect, true
    change_column_null :discourse_size_shop_items, :amount, true
  end
end
