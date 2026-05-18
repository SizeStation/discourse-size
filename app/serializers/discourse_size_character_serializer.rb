# frozen_string_literal: true

class DiscourseSizeCharacterSerializer < ApplicationSerializer
  attributes :id,
             :user_id,
             :username,
             :name,
             :picture,
             :info_post,
             :base_size,
             :current_offset,
             :target_offset,
             :start_offset,
             :offset_updated_at,
             :current_size,
             :blocked_item_keys,
              :blocked_users,
              :blocked_user_ids,
              :measurement_system,
             :is_main,
             :character_type,
             :gender,
             :pronouns,
             :age,
             :species,
             :description,
             :show_comparison,
             :folder_id,
             :position,
             :properties,
             :triggers,
             :roleplay_memberships

  has_many :actions, serializer: DiscourseSizeActionSerializer, embed: :objects

  def actions
    # Return all actions to ensure the history graph is complete
    object.discourse_size_actions.order(created_at: :desc).to_a
  end

  def username
    object.user.username
  end

  def blocked_users
    return [] if object.blocked_user_ids.blank?
    User.where(id: object.blocked_user_ids).map do |user|
      BasicUserSerializer.new(user, scope: scope, root: false).as_json
    end
  end

  def properties
    object.discourse_size_character_properties.map do |prop|
      {
        id: prop.id,
        name: prop.name,
        property_type: prop.property_type,
        value: prop.value,
        effective_value: prop.effective_value,
      }
    end
  end

  def triggers
    object.discourse_size_character_triggers.map do |t|
      {
        id: t.id,
        name: t.name,
        js_code: t.js_code
      }
    end
  end

  def roleplay_memberships
    object.discourse_size_roleplay_members.map do |m|
      {
        id: m.id,
        roleplay_id: m.roleplay_id,
        roleplay_name: m.discourse_size_roleplay.name,
        status: m.status
      }
    end
  end

  def measurement_system
    viewing_user = scope.user || object.user
    DiscourseSizeUserSetting.for_user(viewing_user).measurement_system
  end
end
