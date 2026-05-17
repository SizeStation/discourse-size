# frozen_string_literal: true

class AddCharacterTypeToCharacters < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_size_characters, :character_type, :string, default: 'game', null: false
  end
end
