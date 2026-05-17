# frozen_string_literal: true

class DiscourseSizeRoleplay < ActiveRecord::Base
  belongs_to :creator, class_name: "User"
  has_many :discourse_size_roleplay_members, foreign_key: "roleplay_id", dependent: :destroy
  has_many :characters, through: :discourse_size_roleplay_members

  validates :name, presence: true
  
  before_create :generate_uuid

  def generate_uuid
    self.uuid ||= SecureRandom.uuid
  end

  def to_param
    uuid
  end
end

# == Schema Information
#
# Table name: discourse_size_roleplays
#
#  id          :bigint           not null, primary key
#  description :text
#  is_public   :boolean          default(TRUE), not null
#  name        :string           not null
#  picture     :string
#  uuid        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  creator_id  :bigint           not null
#
# Indexes
#
#  index_discourse_size_roleplays_on_creator_id  (creator_id)
#  index_discourse_size_roleplays_on_uuid        (uuid) UNIQUE
#
