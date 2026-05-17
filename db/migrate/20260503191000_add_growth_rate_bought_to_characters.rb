# frozen_string_literal: true

class AddGrowthRateBoughtToCharacters < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_size_characters, :growth_rate_bought, :float, default: 0.0, null: false
  end
end
