# frozen_string_literal: true

class DiscourseSizeActionSerializer < ApplicationSerializer
  attributes :id,
             :user_id,
             :action_type,
             :size_change,
             :points_spent,
             :created_at,
             :item_key,
             :item_name,
             :is_user_blocked,
             :duration_minutes,
             :start_time,
             :end_time,
             :start_offset,
             :end_offset,
             :parent_action_id,
             :target_character_name,
             :target_character_id,
             :target_owner_username,
             :character_owner_username,
             :character_id,
             :child_action_id,
             :child_character_name,
             :child_character_id,
             :child_character_owner_username,
             :child_size_change,
             :child_action_type,
             :parent_size_change,
             :parent_action_type,
             :end_total_size
  
  has_one :user, serializer: UserNameSerializer, embed: :objects

  def character_owner_username
    object.character&.user&.username
  end

  def character_id
    object.character_id
  end

  def child_action
    @child_action ||= DiscourseSizeAction.find_by(parent_action_id: object.id)
  end

  def child_action_id
    child_action&.id
  end

  def child_character_name
    child_action&.character&.name
  end

  def child_character_id
    child_action&.character_id
  end

  def child_character_owner_username
    child_action&.character&.user&.username
  end

  def child_size_change
    child_action&.size_change.to_f
  end

  def child_action_type
    child_action&.action_type
  end

  def parent_size_change
    object.parent_action&.size_change.to_f
  end

  def parent_action_type
    object.parent_action&.action_type
  end

  def target_character_name
    return nil unless object.parent_action_id
    object.parent_action&.character&.name
  end

  def target_character_id
    return nil unless object.parent_action_id
    object.parent_action&.character_id
  end

  def target_owner_username
    return nil unless object.parent_action_id
    object.parent_action&.character&.user&.username
  end

  def points_spent
    object.points_spent.to_f
  end

  def duration_minutes
    object.duration_minutes.to_i
  end

  def start_time
    object.start_time
  end

  def end_time
    object.end_time
  end

  def start_offset
    object.start_offset.to_f
  end

  def end_offset
    object.end_offset.to_f
  end

  def end_total_size
    return nil unless object.character
    object.character.base_size + object.end_offset.to_f
  end

  def item_name
    if object.action_type == "trigger"
      return object.item_key
    end
    return nil unless object.item_key
    DiscourseSizeShopItem.find_by(key: object.item_key)&.name
  end

  def is_user_blocked
    return false unless object.character
    return false if object.user_id == object.character.user_id
    return false if object.character.blocked_user_ids.blank?
    object.character.blocked_user_ids.map(&:to_i).include?(object.user_id.to_i)
  end

  def item_picture
    return nil unless object.item_key
    DiscourseSizeShopItem.find_by(key: object.item_key)&.picture
  end
end
