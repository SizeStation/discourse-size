# frozen_string_literal: true

class DiscourseSizeAction < ActiveRecord::Base
  belongs_to :character, class_name: 'DiscourseSizeCharacter'
  belongs_to :user

  validates :character_id, presence: true
  validates :user_id, presence: true
  validates :action_type, presence: true, inclusion: { in: %w[grow shrink reset] }
  validates :size_change, presence: true
end
