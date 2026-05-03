# frozen_string_literal: true

class CreateDiscourseSizeTables < ActiveRecord::Migration[7.0]
  def change
    create_table :discourse_size_characters do |t|
      t.integer :user_id, null: false
      t.string :name, null: false
      t.string :picture
      t.string :info_post
      t.float :base_size, null: false
      t.float :current_offset, null: false, default: 0.0
      t.float :target_offset, null: false, default: 0.0
      t.datetime :offset_updated_at, null: false
      t.float :growth_rate_override
      t.boolean :allow_growth, null: false, default: true
      t.boolean :allow_shrink, null: false, default: true
      t.string :measurement_system, null: false, default: "imperial"
      t.boolean :is_main, null: false, default: false

      t.timestamps
    end

    add_index :discourse_size_characters, :user_id
    add_index :discourse_size_characters, [:user_id, :is_main], unique: true, where: "is_main = true"

    create_table :discourse_size_actions do |t|
      t.integer :character_id, null: false
      t.integer :user_id, null: false
      t.string :action_type, null: false
      t.float :size_change, null: false
      
      t.timestamps
    end

    add_index :discourse_size_actions, :character_id

  end
end
