# frozen_string_literal: true

class AddColorToFoldersAndNotificationToActions < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_size_folders, :hex_color, :string
    add_column :discourse_size_actions, :notification_id, :integer
  end
end
