# frozen_string_literal: true

class AddSpeedToDiscourseSizeActions < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_size_actions, :speed, :float, default: 1.0, null: false
    add_column :discourse_size_actions, :start_offset, :float
    add_column :discourse_size_actions, :end_offset, :float
  end
end
