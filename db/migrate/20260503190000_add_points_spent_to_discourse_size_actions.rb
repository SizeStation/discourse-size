# frozen_string_literal: true

class AddPointsSpentToDiscourseSizeActions < ActiveRecord::Migration[7.2]
  def change
    add_column :discourse_size_actions, :points_spent, :float, default: 0.0, null: false
  end
end
