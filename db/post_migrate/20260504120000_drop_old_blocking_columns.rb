# frozen_string_literal: true

class DropOldBlockingColumns < ActiveRecord::Migration[7.0]
  def change
    if column_exists?(:discourse_size_characters, :allow_growth)
      remove_column :discourse_size_characters, :allow_growth, :boolean, default: true, null: false
    end
    if column_exists?(:discourse_size_characters, :allow_shrink)
      remove_column :discourse_size_characters, :allow_shrink, :boolean, default: true, null: false
    end
  end
end
