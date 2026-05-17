# frozen_string_literal: true

class RemoveMeasurementSystemFromCharacters < ActiveRecord::Migration[7.0]
  def change
    if column_exists?(:discourse_size_characters, :measurement_system)
      remove_column :discourse_size_characters, :measurement_system, :string, default: "imperial", null: false
    end
  end
end
