# frozen_string_literal: true

class UpdateCharacterBlocking < ActiveRecord::Migration[7.0]
  def change
    unless column_exists?(:discourse_size_characters, :blocked_item_keys)
      add_column :discourse_size_characters, :blocked_item_keys, :jsonb, default: [], null: false
    end
    
    unless column_exists?(:discourse_size_characters, :blocked_user_ids)
      add_column :discourse_size_characters, :blocked_user_ids, :jsonb, default: [], null: false
    end

    unless index_exists?(:discourse_size_characters, :blocked_item_keys)
      add_index :discourse_size_characters, :blocked_item_keys, using: :gin
    end

    unless index_exists?(:discourse_size_characters, :blocked_user_ids)
      add_index :discourse_size_characters, :blocked_user_ids, using: :gin
    end
  end
end
