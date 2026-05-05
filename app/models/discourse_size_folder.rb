# frozen_string_literal: true

class DiscourseSizeFolder < ActiveRecord::Base
  belongs_to :user
  has_many :discourse_size_characters, foreign_key: "folder_id", dependent: :nullify

  validates :name, presence: true
  validates :user_id, presence: true

  def self.reorder(user, mapping)
    mapping.each do |id, position|
      where(id: id, user_id: user.id).update_all(position: position)
    end
  end
end
