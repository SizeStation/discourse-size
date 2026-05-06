# frozen_string_literal: true

class CreateDiscourseSizeEconomicTables < ActiveRecord::Migration[7.0]
  def change
    create_table :discourse_size_point_history do |t|
      t.integer :user_id, null: false
      t.float :amount, null: false
      t.string :source_type, null: false
      t.text :description
      t.timestamps
    end

    add_index :discourse_size_point_history, :user_id

    create_table :discourse_size_inventory do |t|
      t.integer :user_id, null: false
      t.string :item_key, null: false
      t.integer :uses_remaining, null: false, default: 0
      t.timestamps
    end

    add_index :discourse_size_inventory, :user_id
    add_index :discourse_size_inventory, [:user_id, :item_key]
  end
end
