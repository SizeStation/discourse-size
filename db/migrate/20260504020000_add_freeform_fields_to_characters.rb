# frozen_string_literal: true

class AddFreeformFieldsToCharacters < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_size_characters, :gender, :string
    add_column :discourse_size_characters, :pronouns, :string
    add_column :discourse_size_characters, :age, :string
    add_column :discourse_size_characters, :description, :text
  end
end
