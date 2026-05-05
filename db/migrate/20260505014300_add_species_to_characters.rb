# frozen_string_literal: true

class AddSpeciesToCharacters < ActiveRecord::Migration[7.1]
  def change
    add_column :discourse_size_characters, :species, :string
  end
end
