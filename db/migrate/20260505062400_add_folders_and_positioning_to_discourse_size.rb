# frozen_string_literal: true

class AddFoldersAndPositioningToDiscourseSize < ActiveRecord::Migration[7.0]
  def change
    create_table :discourse_size_folders do |t|
      t.integer :user_id, null: false
      t.string :name, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end

    add_index :discourse_size_folders, :user_id

    add_column :discourse_size_characters, :folder_id, :integer
    add_column :discourse_size_characters, :position, :integer, default: 0, null: false
    add_index :discourse_size_characters, :folder_id
  end
end
