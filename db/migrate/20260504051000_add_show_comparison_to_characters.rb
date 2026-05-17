# frozen_string_literal: true

class AddShowComparisonToCharacters < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_size_characters, :show_comparison, :boolean, default: true, null: false
  end
end
