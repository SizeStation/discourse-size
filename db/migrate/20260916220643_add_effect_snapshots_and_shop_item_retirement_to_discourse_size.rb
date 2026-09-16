# frozen_string_literal: true

class AddEffectSnapshotsAndShopItemRetirementToDiscourseSize < ActiveRecord::Migration[8.0]
  def change
    add_column :discourse_size_actions, :effect_type, :string
    add_column :discourse_size_actions, :effect_amount, :float
    add_column :discourse_size_shop_items, :deleted_at, :datetime
  end
end
