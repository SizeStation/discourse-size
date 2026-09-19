# frozen_string_literal: true

class AddAbsoluteEndpointsToDiscourseSizeActions < ActiveRecord::Migration[8.0]
  def change
    # Non-height actions and rows awaiting the post-deploy backfill have no endpoints.
    add_column :discourse_size_actions, :start_size, :float, null: true
    add_column :discourse_size_actions, :end_size, :float, null: true
  end
end
