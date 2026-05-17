# frozen_string_literal: true

class CreateDiscourseSizeShopItems < ActiveRecord::Migration[7.0]
  def change
    create_table :discourse_size_shop_items do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.integer :price, default: 0, null: false
      t.string :effect, null: false # grow or shrink
      t.float :amount, null: false # percentage
      t.float :speed, default: 1.0, null: false
      t.integer :uses, default: 1, null: false # usages per purchase
      t.string :picture
      t.integer :stock, default: -1, null: false # -1 for infinite
      t.boolean :enabled, default: true, null: false
      t.timestamps
    end

    add_index :discourse_size_shop_items, :key, unique: true
  end
end
