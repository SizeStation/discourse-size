# frozen_string_literal: true

class AddParentActionIdToDiscourseSizeActions < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_size_actions, :parent_action_id, :bigint
    add_index :discourse_size_actions, :parent_action_id
  end
end
