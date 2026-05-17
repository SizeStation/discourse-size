# frozen_string_literal: true

class DiscourseSizeCharacterTrigger < ActiveRecord::Base
  belongs_to :character, class_name: "DiscourseSizeCharacter"

  validates :name, presence: true
  validates :js_code, presence: true
end
