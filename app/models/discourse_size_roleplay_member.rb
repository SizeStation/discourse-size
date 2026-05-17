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

# == Schema Information
#
# Table name: discourse_size_roleplay_members
#
#  id           :bigint           not null, primary key
#  status       :string           default("accepted"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  character_id :bigint           not null
#  roleplay_id  :bigint           not null
#
# Indexes
#
#  idx_ds_rp_members_rp_char  (roleplay_id,character_id) UNIQUE
#
