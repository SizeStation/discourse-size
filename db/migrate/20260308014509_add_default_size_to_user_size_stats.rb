# frozen_string_literal: true

class AddDefaultSizeToUserSizeStats < ActiveRecord::Migration[7.0]
  def change
    add_column :user_size_stats, :default_size, :float, default: 170.0, null: false
  end
end
