# frozen_string_literal: true

class DiscourseSizeCharacterTrigger < ActiveRecord::Base
  belongs_to :character, class_name: "DiscourseSizeCharacter"

  validates :name, presence: true
  validates :js_code, presence: true
end

# == Schema Information
#
# Table name: discourse_size_character_triggers
#
#  id           :bigint           not null, primary key
#  js_code      :text             not null
#  name         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  character_id :bigint           not null
#
# Indexes
#
#  index_discourse_size_character_triggers_on_character_id  (character_id)
#
