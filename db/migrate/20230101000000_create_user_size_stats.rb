# frozen_string_literal: true

class CreateUserSizeStats < ActiveRecord::Migration[7.0]
  def change
    create_table :user_size_stats do |t|
      t.integer :user_id, null: false
      t.float :base_size, null: false, default: 170.0
      t.float :target_size, null: false, default: 170.0
      t.float :growth_rate, null: false, default: 0.1
      t.datetime :size_updated_at, null: false
      t.integer :points, null: false, default: 0
      t.integer :measurement_system, null: false, default: 0 # 0 -> System, 1 -> Metric, 2 -> Imperial
      t.boolean :consent_grow, null: false, default: false
      t.boolean :consent_shrink, null: false, default: false
      t.boolean :ranking_public, null: false, default: true
      t.integer :character_upload_id

      t.timestamps
    end

    add_index :user_size_stats, :user_id, unique: true
    add_index :user_size_stats, :points
    add_index :user_size_stats, :target_size
  end
end
