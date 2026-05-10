# frozen_string_literal: true

class ChangeIdsToBigint < ActiveRecord::Migration[7.0]
  def up
    # discourse_size_characters
    change_column :discourse_size_characters, :user_id, :bigint
    change_column :discourse_size_characters, :folder_id, :bigint

    # discourse_size_actions
    change_column :discourse_size_actions, :character_id, :bigint
    change_column :discourse_size_actions, :user_id, :bigint

    # discourse_size_point_history
    change_column :discourse_size_point_history, :user_id, :bigint

    # discourse_size_inventory
    change_column :discourse_size_inventory, :user_id, :bigint

    # discourse_size_folders
    change_column :discourse_size_folders, :user_id, :bigint

    # discourse_size_user_settings
    change_column :discourse_size_user_settings, :user_id, :bigint

    # discourse_size_user_quests
    change_column :discourse_size_user_quests, :user_id, :bigint
  end

  def down
    change_column :discourse_size_characters, :user_id, :integer
    change_column :discourse_size_characters, :folder_id, :integer
    change_column :discourse_size_actions, :character_id, :integer
    change_column :discourse_size_actions, :user_id, :integer
    change_column :discourse_size_point_history, :user_id, :integer
    change_column :discourse_size_inventory, :user_id, :integer
    change_column :discourse_size_folders, :user_id, :integer
    change_column :discourse_size_user_settings, :user_id, :integer
    change_column :discourse_size_user_quests, :user_id, :integer
  end
end
