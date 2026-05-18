# frozen_string_literal: true

class AddOverrideDataToRoleplayMembers < ActiveRecord::Migration[7.1]
  def up
    add_column :discourse_size_roleplay_members, :override_data, :jsonb, default: {}, null: false
    # Change character_type default/validation — add 'normal', remove 'roleplay' from allowed values
    # We update existing 'freeform' records to 'normal' and 'roleplay' records to 'normal'
    execute <<~SQL
      UPDATE discourse_size_characters SET character_type = 'normal' WHERE character_type IN ('freeform', 'roleplay');
    SQL
  end

  def down
    remove_column :discourse_size_roleplay_members, :override_data
  end
end
