# frozen_string_literal: true

class AddStartOffsetToCharacters < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_size_characters, :start_offset, :float, default: 0.0, null: false
    
    # Initialize start_offset with current_offset for existing characters
    up_only do
      execute "UPDATE discourse_size_characters SET start_offset = current_offset"
    end
  end
end
