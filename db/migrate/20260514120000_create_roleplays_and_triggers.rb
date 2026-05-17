# frozen_string_literal: true

class CreateRoleplaysAndTriggers < ActiveRecord::Migration[7.0]
  def change
    create_table :discourse_size_roleplays, if_not_exists: true do |t|
      t.string :name, null: false
      t.text :description
      t.bigint :creator_id, null: false
      t.boolean :is_public, default: true, null: false
      t.timestamps
    end

    create_table :discourse_size_roleplay_members, if_not_exists: true do |t|
      t.bigint :roleplay_id, null: false
      t.bigint :character_id, null: false
      t.timestamps
    end

    create_table :discourse_size_character_triggers, if_not_exists: true do |t|
      t.bigint :character_id, null: false
      t.string :name, null: false
      t.text :js_code, null: false
      t.timestamps
    end

    add_index :discourse_size_roleplays, :creator_id, if_not_exists: true
    add_index :discourse_size_roleplay_members, [:roleplay_id, :character_id], unique: true, name: 'idx_ds_rp_members_rp_char', if_not_exists: true
    add_index :discourse_size_character_triggers, :character_id, if_not_exists: true
  end
end
