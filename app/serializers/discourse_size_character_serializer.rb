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
             :is_biggest,
             :is_tiniest,
             :biggest_rank,
             :tiniest_rank

  has_many :actions, serializer: DiscourseSizeActionSerializer, embed: :objects

  def actions
    # We need all pending actions for growth calculation, plus some recent ones for display
    is_growing = object.target_offset > object.current_offset
    is_shrinking = object.target_offset < object.current_offset
    
    pending_query = object.discourse_size_actions.where(action_type: ["grow", "shrink"])
    if is_growing
      pending_query = pending_query.where("end_offset > ?", object.current_offset)
    elsif is_shrinking
      pending_query = pending_query.where("end_offset < ?", object.current_offset)
    else
      pending_query = pending_query.none
    end

    recent_actions = object.discourse_size_actions.order(created_at: :desc).limit(10).to_a
    pending_actions = pending_query.order(created_at: :asc).to_a
    
    (pending_actions + recent_actions).uniq(&:id).sort_by(&:created_at).reverse
  end

  def username
    object.user.username
  end

  def is_biggest
    return false unless object.game?
    @biggest_character_id ||= DiscourseSizeCharacter.where(character_type: "game").order(Arel.sql("(base_size + current_offset) DESC")).limit(1).pluck(:id).first
    object.id == @biggest_character_id && DiscourseSizeCharacter.count > 1
  end

  def is_tiniest
    return false unless object.game?
    @tiniest_character_id ||= DiscourseSizeCharacter.where(character_type: "game").order(Arel.sql("(base_size + current_offset) ASC")).limit(1).pluck(:id).first
    object.id == @tiniest_character_id && DiscourseSizeCharacter.count > 1
  end

  def biggest_rank
    return nil unless object.game?
    DiscourseSizeCharacter.where(character_type: "game").where(
      "(base_size + current_offset) > ?",
      object.base_size + object.current_offset
    ).count + 1
  end

  def tiniest_rank
    return nil unless object.game?
    DiscourseSizeCharacter.where(character_type: "game").where(
      "(base_size + current_offset) < ?",
      object.base_size + object.current_offset
    ).count + 1
  end

  def blocked_users
    return [] if object.blocked_user_ids.blank?
    User.where(id: object.blocked_user_ids).map do |user|
      BasicUserSerializer.new(user, scope: scope, root: false).as_json
    end
  end
end
