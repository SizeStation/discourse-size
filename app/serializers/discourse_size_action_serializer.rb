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
             :end_offset
  
  has_one :user, serializer: UserNameSerializer, embed: :objects

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

  def item_name
    return nil unless object.item_key
    DiscourseSizeShopItem.find_by(key: object.item_key)&.name
  end

  def is_user_blocked
    return false unless object.character
    return false if object.user_id == object.character.user_id
    return false if object.character.blocked_user_ids.blank?
    object.character.blocked_user_ids.map(&:to_i).include?(object.user_id.to_i)
  end
end
