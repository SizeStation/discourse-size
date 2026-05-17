# frozen_string_literal: true

class DiscourseSizeCharacterProperty < ActiveRecord::Base
  belongs_to :character, class_name: "DiscourseSizeCharacter"

  validates :name, presence: true
  validates :property_type, inclusion: { in: %w[size text number] }

  before_save :calculate_link_ratio

  def calculate_link_ratio
    if property_type == 'size' && linked_to_size
      val = value.to_f
      char_size = character.current_size
      self.link_ratio = char_size > 0 ? (val / char_size).to_f : 0
    else
      self.link_ratio = nil
    end
  end

  def effective_value
    if property_type == 'size' && linked_to_size && link_ratio.present?
      (character.current_size * link_ratio).to_f
    else
      value
    end
  end

  def formatted_value
    val = effective_value
    if property_type == 'size'
      # We might want to use the character's measurement system here
      # For now, just return as is or handle in serializer
      val
    else
      val
    end
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
