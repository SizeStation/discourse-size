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

  OVERRIDABLE_FIELDS = %w[
    name base_size gender pronouns age species description picture
    info_post show_comparison is_main
    blocked_item_keys blocked_user_ids
    properties triggers
  ].freeze

  def effective_value(field)
    return override_data[field] if override_data&.key?(field)
    character&.public_send(field)
  end

  def deviates?(field)
    return false unless override_data&.key?(field)
    override_data[field] != character&.public_send(field)&.to_s
  end

  def reset_override!(field)
    data = override_data.dup
    data.delete(field.to_s)
    update!(override_data: data)
  end

  def reset_all_overrides!
    update!(override_data: {})
  end
end

# == Schema Information
#
# Table name: discourse_size_roleplay_members
#
#  id            :bigint           not null, primary key
#  override_data :jsonb            not null
#  status        :string           default("accepted"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  character_id  :bigint           not null
#  roleplay_id   :bigint           not null
#
# Indexes
#
#  idx_ds_rp_members_rp_char  (roleplay_id,character_id) UNIQUE
#
