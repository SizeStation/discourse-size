# frozen_string_literal: true

class RoleplayMemberSerializer < ApplicationSerializer
  attributes :id,
             :roleplay_id,
             :character_id,
             :status,
             :override_data,
             :character_name,
             :character_base_size,
             :character

  def character_name
    object.override_data&.key?("name") ? object.override_data["name"] : object.character&.name
  end

  def character_base_size
    if object.override_data&.key?("base_size")
      object.override_data["base_size"]
    elsif object.character&.base_size&.infinite?
      object.character.base_size.negative? ? "-Infinity" : "Infinity"
    else
      object.character&.base_size
    end
  end

  def override_data
    object.override_data
  end

  def character
    DiscourseSizeCharacterSerializer.new(object.character, scope: scope, root: false).as_json
  end
end
