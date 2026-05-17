# frozen_string_literal: true

class RoleplayMemberSerializer < ApplicationSerializer
  attributes :id, :roleplay_id, :character_id, :status
  
  has_one :character, serializer: DiscourseSizeCharacterSerializer, embed: :objects
end
