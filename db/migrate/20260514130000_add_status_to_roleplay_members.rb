# frozen_string_literal: true

class AddStatusToRoleplayMembers < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_size_roleplay_members, :status, :string, default: 'accepted', null: false
  end
end
