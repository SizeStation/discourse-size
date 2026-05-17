# frozen_string_literal: true

class CreateDiscourseSizeCharacterProperties < ActiveRecord::Migration[7.0]
  def change
    create_table :discourse_size_character_properties do |t|
      t.bigint :character_id, null: false
      t.string :name, null: false
      t.string :property_type, default: 'text', null: false # 'size', 'text', 'number'
      t.string :value
      t.boolean :linked_to_size, default: false, null: false
      t.float :link_ratio
      t.timestamps
    end

    add_index :discourse_size_character_properties, :character_id
  end
end
