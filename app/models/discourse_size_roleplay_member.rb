# frozen_string_literal: true

class DiscourseSizeRoleplayMember < ActiveRecord::Base
  belongs_to :discourse_size_roleplay, foreign_key: "roleplay_id"
  belongs_to :character, class_name: "DiscourseSizeCharacter"

  validates :roleplay_id, uniqueness: { scope: :character_id }
  validates :status, inclusion: { in: %w[pending accepted] }

  def pending?
    status == 'pending'
  end

  def accepted?
    status == 'accepted'
  end
end
