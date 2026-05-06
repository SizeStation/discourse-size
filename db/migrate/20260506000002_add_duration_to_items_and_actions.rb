# frozen_string_literal: true

class AddDurationToItemsAndActions < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_size_shop_items, :duration_minutes, :integer, default: 60, null: false
    
    add_column :discourse_size_actions, :duration_minutes, :integer, default: 0
    add_column :discourse_size_actions, :start_time, :datetime
    add_column :discourse_size_actions, :end_time, :datetime
  end
end
