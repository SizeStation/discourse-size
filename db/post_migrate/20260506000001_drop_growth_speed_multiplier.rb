# frozen_string_literal: true

class DropGrowthSpeedMultiplier < ActiveRecord::Migration[7.0]
  def up
    if column_exists?(:discourse_size_characters, :growth_speed_multiplier)
      remove_column :discourse_size_characters, :growth_speed_multiplier
    end
  end

  def down
    if !column_exists?(:discourse_size_characters, :growth_speed_multiplier)
      add_column :discourse_size_characters, :growth_speed_multiplier, :float, default: 1.0, null: false
    end
  end
end
