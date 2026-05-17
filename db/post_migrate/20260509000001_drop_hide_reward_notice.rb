# frozen_string_literal: true

class DropHideRewardNotice < ActiveRecord::Migration[7.0]
  def up
    remove_column :discourse_size_user_settings, :hide_reward_notice
  end

  def down
    add_column :discourse_size_user_settings, :hide_reward_notice, :boolean, default: false, null: false
  end
end
