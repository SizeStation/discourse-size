# frozen_string_literal: true

class DiscourseSizeCharacter < ActiveRecord::Base
  belongs_to :user
  belongs_to :discourse_size_folder, foreign_key: "folder_id", optional: true
  before_validation :trim_fields
  before_save :ensure_single_main, if: :is_main?
  before_save :set_folder_position, if: :will_save_change_to_folder_id?
  before_create :set_default_position

  self.ignored_columns = %w[allow_growth allow_shrink growth_speed_multiplier]

  def set_default_position
    return if position.present?
    if folder_id.nil?
      max_char = DiscourseSizeCharacter.where(user_id: user_id, folder_id: nil).maximum(:position) || 0
      max_folder = DiscourseSizeFolder.where(user_id: user_id).maximum(:position) || 0
      self.position = [max_char, max_folder].max + 1
    else
      self.position = DiscourseSizeCharacter.where(folder_id: folder_id).maximum(:position).to_i + 1
    end
  end

  def set_folder_position
    return unless folder_id && will_save_change_to_folder_id?
    self.position = DiscourseSizeCharacter.where(folder_id: folder_id).maximum(:position).to_i + 1
  end

  validates :name, presence: true
  validates :base_size, presence: true

  def self.reorder(user, mapping)
    mapping.each do |id, position|
      where(id: id, user_id: user.id).update_all(position: position)
    end
  end

  def self.move_to_folder(user, character_ids, folder_id)
    where(id: character_ids, user_id: user.id).update_all(folder_id: folder_id)
  end
  validates :base_size,
            numericality: {
              greater_than_or_equal_to: -> { SiteSetting.discourse_size_min_base_size },
              less_than_or_equal_to: -> { SiteSetting.discourse_size_max_base_size },
            },
            if: :game?
  validates :user_id, presence: true

  has_many :discourse_size_actions, foreign_key: "character_id", dependent: :destroy

  TYPE_GAME = 'game'
  TYPE_FREEFORM = 'freeform'

  validates :character_type, inclusion: { in: [TYPE_GAME, TYPE_FREEFORM] }

  def game?
    character_type == TYPE_GAME
  end

  def freeform?
    character_type == TYPE_FREEFORM
  end

  MAX_SIZE = 1e120 # Cap at a googol-plus to prevent Infinity overflow

  def update_size_target(amount)
    sync_offset!
    self.start_offset = self.current_offset
    self.offset_updated_at = Time.now
    new_target = self.target_offset + amount
 
    # Cap total size
    if (self.base_size + new_target) > MAX_SIZE
      new_target = MAX_SIZE - self.base_size
    end
 
    # Floor total size at a nanoscopic value (1e-18 cm) to prevent true zero/negative
    new_target = 1e-18 - self.base_size if (self.base_size + new_target) < 1e-18
 
    self.target_offset = new_target
    save!
  end

  def current_size
    base_size + current_calculated_offset
  end

  def current_calculated_offset
    return current_offset if target_offset == current_offset || offset_updated_at.nil?
    
    now = Time.now
    # Find the action that is currently active
    active_action = discourse_size_actions.where(action_type: ["grow", "shrink"])
      .where("start_time <= ? AND end_time > ?", now, now)
      .first
    
    if active_action
      # Linear interpolation within the action duration
      start_t = active_action.start_time
      end_t = active_action.end_time
      total_duration = end_t - start_t
      
      if total_duration > 0
        elapsed = now - start_t
        progress = elapsed / total_duration
        
        start_off = active_action.start_offset
        end_off = active_action.end_offset
        
        return start_off + (end_off - start_off) * progress
      else
        return active_action.end_offset
      end
    end

    # If no active action, check if we are in between actions or after all actions
    next_action = discourse_size_actions.where(action_type: ["grow", "shrink"])
      .where("start_time > ?", now)
      .order(start_time: :asc)
      .first
      
    if next_action
      # We are waiting for the next action to start.
      # The size should be the end of the previous segment (start of next)
      return next_action.start_offset
    end
    
    # Otherwise, all actions are complete
    target_offset
  end

  def time_remaining_seconds
    return 0 if (target_offset - current_offset).abs < 0.0001
    
    last_action = discourse_size_actions.where(action_type: ["grow", "shrink"]).order(end_time: :desc).first
    return 0 if last_action&.end_time.nil?
    
    now = Time.now
    return 0 if last_action.end_time <= now
    
    (last_action.end_time - now).to_i
  end

  def sync_offset!
    new_offset = current_calculated_offset
    if new_offset != current_offset
      self.current_offset = new_offset
      self.offset_updated_at = Time.now
      self.save!
    end
  end

  def is_blocked?(user, item_key: nil, action_type: nil)
    return false if user.nil?
    return false if user.id == user_id # Owner is never blocked

    # Check user block
    return true if blocked_user_ids.include?(user.id)
    
    # Check global/bulk blocks
    return true if blocked_item_keys.include?("__all__")

    # If it's a shop item, action_type is determined by the item's effect
    if item_key
      return true if blocked_item_keys.include?(item_key)
      item = DiscourseSizeShopItem.find_by(key: item_key)
      if item
        return true if item.effect == "grow" && blocked_item_keys.include?("__all_growing__")
        return true if item.effect == "shrink" && blocked_item_keys.include?("__all_shrinking__")
      end
    end

    # Check direct action blocks
    if action_type == "grow"
      return true if blocked_item_keys.include?("__all_growing__")
      return true if blocked_item_keys.include?("__direct_grow__")
    elsif action_type == "shrink"
      return true if blocked_item_keys.include?("__all_shrinking__")
      return true if blocked_item_keys.include?("__direct_shrink__")
    end

    false
  end

  private

  def trim_fields
    self.name = name&.strip
    self.picture = picture&.strip
    self.info_post = info_post&.strip
    self.gender = gender&.strip
    self.pronouns = pronouns&.strip
    self.age = age&.strip
    self.species = species&.strip
    self.description = description&.strip
  end

  def ensure_single_main
    self.folder_id = nil
    DiscourseSizeCharacter
      .where(user_id: user_id, is_main: true)
      .where.not(id: id)
      .update_all(is_main: false)
  end
end

# == Schema Information
#
# Table name: discourse_size_characters
#
#  id                   :bigint           not null, primary key
#  age                  :string
#  base_size            :float            not null
#  blocked_item_keys    :jsonb            not null
#  blocked_user_ids     :jsonb            not null
#  character_type       :string           default("game"), not null
#  current_offset       :float            default(0.0), not null
#  description          :text
#  gender               :string
#  growth_rate_bought   :float            default(0.0), not null
#  growth_rate_override :float
#  info_post            :string
#  is_main              :boolean          default(FALSE), not null
#  measurement_system   :string           default("imperial"), not null
#  name                 :string           not null
#  offset_updated_at    :datetime         not null
#  picture              :string
#  position             :integer          default(0), not null
#  pronouns             :string
#  show_comparison      :boolean          default(TRUE), not null
#  species              :string
#  start_offset         :float            default(0.0), not null
#  target_offset        :float            default(0.0), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  folder_id            :integer
#  user_id              :integer          not null
#
# Indexes
#
#  index_discourse_size_characters_on_blocked_item_keys    (blocked_item_keys) USING gin
#  index_discourse_size_characters_on_blocked_user_ids     (blocked_user_ids) USING gin
#  index_discourse_size_characters_on_folder_id            (folder_id)
#  index_discourse_size_characters_on_user_id              (user_id)
#  index_discourse_size_characters_on_user_id_and_is_main  (user_id,is_main) UNIQUE WHERE (is_main = true)
#
