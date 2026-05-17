# frozen_string_literal: true

class AddGrowthSpeedMultiplierToCharacters < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_size_characters, :growth_speed_multiplier, :float, default: 1.0, null: false
  end
end
