# frozen_string_literal: true

class AddSiteSinkToCharacters < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_size_characters, :site_sink, :boolean, default: false, null: false
  end
end
