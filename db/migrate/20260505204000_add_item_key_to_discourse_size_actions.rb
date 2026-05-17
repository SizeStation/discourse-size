# frozen_string_literal: true

class AddItemKeyToDiscourseSizeActions < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_size_actions, :item_key, :string
  end
end
