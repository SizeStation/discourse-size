# frozen_string_literal: true

class DiscourseSizeCharacterProperty < ActiveRecord::Base
  belongs_to :character, class_name: "DiscourseSizeCharacter"

  validates :name, presence: true
  validates :property_type, inclusion: { in: %w[size text number] }

  def effective_value
    interpolated_value || value
  end

  def formatted_value
    effective_value
  end

  def interpolated_value
    active_action = character.discourse_size_actions
      .where(action_type: "property_change", item_key: name)
      .where("start_time <= ? AND end_time > ?", Time.now, Time.now)
      .first

    if active_action
      total = active_action.end_time - active_action.start_time
      if total > 0
        progress = (Time.now - active_action.start_time) / total
        interpolated = active_action.start_offset + (active_action.end_offset - active_action.start_offset) * progress
        return interpolated.to_s if property_type == 'size' || property_type == 'number'
        return interpolated.round.to_s
      end
    end

    # If action has passed end_time but value wasn't finalized, update it
    expired_action = character.discourse_size_actions
      .where(action_type: "property_change", item_key: name)
      .where("end_time <= ?", Time.now)
      .where.not(end_time: nil)
      .order(end_time: :desc)
      .first

    if expired_action && expired_action.end_offset.to_s != value
      update_column(:value, expired_action.end_offset.to_s)
      self.value = expired_action.end_offset.to_s
    end

    nil
  end
end

# == Schema Information
#
# Table name: discourse_size_character_properties
#
#  id             :bigint           not null, primary key
#  link_ratio     :float
#  linked_to_size :boolean          default(FALSE), not null
#  name           :string           not null
#  property_type  :string           default("text"), not null
#  value          :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  character_id   :bigint           not null
#
# Indexes
#
#  index_discourse_size_character_properties_on_character_id  (character_id)
#
