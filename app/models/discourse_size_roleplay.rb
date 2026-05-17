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
