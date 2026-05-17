# frozen_string_literal: true

class DropSiteSinkFromCharacters < ActiveRecord::Migration[7.0]
  def change
    remove_column :discourse_size_characters, :site_sink, :boolean, default: false, null: false
  end
end
