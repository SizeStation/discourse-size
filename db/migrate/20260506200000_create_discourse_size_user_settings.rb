# frozen_string_literal: true

class CreateDiscourseSizeUserSettings < ActiveRecord::Migration[7.0]
  def change
    create_table :discourse_size_user_settings do |t|
      t.integer :user_id, null: false
      t.string :measurement_system, default: "imperial", null: false
      t.boolean :hide_reward_notice, default: false, null: false
      t.timestamps
    end

    add_index :discourse_size_user_settings, :user_id, unique: true
  end
end
