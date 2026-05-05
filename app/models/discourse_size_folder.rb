# frozen_string_literal: true

class DiscourseSizeFolder < ActiveRecord::Base
  belongs_to :user
  has_many :discourse_size_characters, foreign_key: "folder_id", dependent: :nullify

  validates :name, presence: true
  validates :user_id, presence: true
  before_create :set_default_position

  def set_default_position
    return if position.present?
    max_char = DiscourseSizeCharacter.where(user_id: user_id, folder_id: nil).maximum(:position) || 0
    max_folder = DiscourseSizeFolder.where(user_id: user_id).maximum(:position) || 0
    self.position = [max_char, max_folder].max + 1
  end

  def self.reorder(user, mapping)
    mapping.each do |id, position|
      where(id: id, user_id: user.id).update_all(position: position)
    end
  end
end
