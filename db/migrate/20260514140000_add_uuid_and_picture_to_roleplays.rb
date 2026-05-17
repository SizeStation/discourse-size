# frozen_string_literal: true

class AddUuidAndPictureToRoleplays < ActiveRecord::Migration[7.0]
  def up
    add_column :discourse_size_roleplays, :uuid, :string
    add_column :discourse_size_roleplays, :picture, :string
    add_index :discourse_size_roleplays, :uuid, unique: true

    # Populating UUIDs for existing roleplays
    # We use SecureRandom since gen_random_uuid() might not be available in all environments
    # but Postgres usually has it. Let's try to be safe.
    execute "UPDATE discourse_size_roleplays SET uuid = md5(random()::text || clock_timestamp()::text)::uuid WHERE uuid IS NULL"
  rescue => e
    # Fallback if the above SQL fails (e.g. uuid type not available)
    # We can do it in Ruby
    DiscourseSizeRoleplay.all.each do |rp|
      rp.update_column(:uuid, SecureRandom.uuid)
    end
  end

  def down
    remove_column :discourse_size_roleplays, :uuid
    remove_column :discourse_size_roleplays, :picture
  end
end
