# frozen_string_literal: true

class DiscourseSizeAction < ActiveRecord::Base
  belongs_to :character, class_name: 'DiscourseSizeCharacter'
  belongs_to :user

  validates :character_id, presence: true
  validates :user_id, presence: true
  validates :action_type, presence: true, inclusion: { in: %w[grow shrink reset] }
  validates :size_change, presence: true
end

# == Schema Information
#
# Table name: discourse_size_actions
#
#  id           :bigint           not null, primary key
#  action_type  :string           not null
#  size_change  :float            not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  character_id :integer          not null
#  user_id      :integer          not null
#
# Indexes
#
#  index_discourse_size_actions_on_character_id  (character_id)
#
