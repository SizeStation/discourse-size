# frozen_string_literal: true

class RoleplaySerializer < ApplicationSerializer
  attributes :id, :uuid, :name, :description, :picture, :creator_id, :creator_username, :is_public, :created_at, :members_count, :user_status
  
  has_many :members, serializer: RoleplayMemberSerializer, embed: :objects

  def creator_username
    User.find_by(id: object.creator_id)&.username
  end

  def user_status
    return nil unless scope.user
    member = object.discourse_size_roleplay_members.joins(:character).find_by(discourse_size_characters: { user_id: scope.user.id })
    member&.status
  end

  def members_count
    object.discourse_size_roleplay_members.where(status: 'accepted').count
  end

  def members
    object.discourse_size_roleplay_members
  end
end
