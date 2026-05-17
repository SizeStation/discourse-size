# frozen_string_literal: true

class CreateDiscourseSizeUserQuests < ActiveRecord::Migration[7.0]
  def change
    create_table :discourse_size_user_quests do |t|
      t.integer :user_id, null: false
      t.string :quest_id, null: false
      t.integer :target_count, default: 1, null: false
      t.integer :current_count, default: 0, null: false
      t.boolean :collected, default: false, null: false
      t.integer :reward, default: 0, null: false
      t.timestamps
    end

    add_index :discourse_size_user_quests, :user_id
    add_index :discourse_size_user_quests, [:user_id, :created_at]
  end
end
