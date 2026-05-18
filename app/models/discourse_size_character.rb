# frozen_string_literal: true

class DiscourseSizeCharacter < ActiveRecord::Base
  belongs_to :user
  belongs_to :discourse_size_folder, foreign_key: "folder_id", optional: true
  has_many :discourse_size_character_properties, foreign_key: "character_id", dependent: :destroy
  accepts_nested_attributes_for :discourse_size_character_properties, allow_destroy: true

  has_many :discourse_size_roleplay_members, foreign_key: "character_id", dependent: :destroy
  has_many :discourse_size_roleplays, through: :discourse_size_roleplay_members
  has_many :discourse_size_character_triggers, foreign_key: "character_id", dependent: :destroy
  accepts_nested_attributes_for :discourse_size_character_triggers, allow_destroy: true

  before_validation :trim_fields
  before_save :ensure_single_main, if: :is_main?
  before_save :set_folder_position, if: :will_save_change_to_folder_id?
  before_create :set_default_position

  self.ignored_columns = %w[allow_growth allow_shrink growth_speed_multiplier measurement_system site_sink]

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
  TYPE_NORMAL = 'normal'

  validates :character_type, inclusion: { in: [TYPE_GAME, TYPE_NORMAL] }

  def game?
    character_type == TYPE_GAME
  end

  def normal?
    character_type == TYPE_NORMAL
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

  def update_size(new_total_cm, actor)
    new_total_cm = new_total_cm.to_f
    new_total_cm = 1e-18 if new_total_cm < 1e-18
    new_total_cm = MAX_SIZE if new_total_cm > MAX_SIZE

    old_total_cm = self.current_size
    
    # Stop all pending growth/shrinking
    discourse_size_actions.where(action_type: ["grow", "shrink"]).where("end_time > ?", Time.now).destroy_all

    old_target_offset = target_offset
    new_offset = new_total_cm - base_size
    size_change = new_offset - old_target_offset

    self.current_offset = new_offset
    self.target_offset = new_offset
    self.start_offset = new_offset
    self.offset_updated_at = Time.now
    save!

    DiscourseSizeAction.create!(
      character_id: id,
      user_id: actor.id,
      action_type: "set_size",
      size_change: size_change,
      points_spent: 0,
      start_offset: old_target_offset,
      end_offset: new_offset,
      duration_minutes: 0,
      start_time: Time.now,
      end_time: Time.now
    )

  end

  def current_size
    DiscourseSize::SizeCalculator.calculate_size(self)
  end

  def current_calculated_offset
    DiscourseSize::SizeCalculator.calculate_offset(self)
  end

  def size_at(time)
    DiscourseSize::SizeCalculator.calculate_size(self, time)
  end

  def time_remaining_seconds
    now = Time.now
    active_action = discourse_size_actions.where(action_type: ["grow", "shrink"])
                                         .where("start_time <= ? AND end_time > ?", now, now)
                                         .first
    return 0 unless active_action
    
    (active_action.end_time - now).to_i
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

    if blocked_user_ids.include?(user.id)
      return true
    end

    if blocked_item_keys.include?("__all__")
      return true
    end

    if item_key.present? && blocked_item_keys.include?(item_key)
      return true
    end

    if action_type == "grow"
      return true if blocked_item_keys.include?("__all_growing__")
      return true if blocked_item_keys.include?("__direct_grow__")
    elsif action_type == "shrink"
      return true if blocked_item_keys.include?("__all_shrinking__")
      return true if blocked_item_keys.include?("__direct_shrink__")
    end

    false
  end

  def add_queued_action(action_type:, size_change:, duration_minutes:, user_id:, item_key: nil, parent_action_id: nil)
    sync_offset!
    
    DiscourseSizeAction.create!(
      character_id: id,
      user_id: user_id,
      action_type: action_type,
      size_change: size_change,
      points_spent: 0,
      item_key: item_key,
      start_offset: target_offset,
      end_offset: target_offset + size_change,
      duration_minutes: duration_minutes.to_f,
      start_time: Time.now,
      end_time: Time.now + 1.second, # Placeholder
      parent_action_id: parent_action_id
    )
    
    recalculate_pending_actions!
  end

  def rebuild_offset_chain!
    # Get all actions that affect size
    actions = discourse_size_actions
               .where(action_type: ["grow", "shrink", "set_size"])
               .order(created_at: :asc)
    
    current_chain_offset = 0.0
    
    actions.each do |action|
      action.start_offset = current_chain_offset
      action.end_offset = current_chain_offset + action.size_change
      action.save!
      current_chain_offset = action.end_offset
    end
    
    self.target_offset = current_chain_offset
    self.save!
    
    # After rebuilding the chain, we need to update the current interpolated offset
    sync_offset!
  end

  def recalculate_pending_actions!
    # Always rebuild from the beginning to ensure absolute sync with the log
    rebuild_offset_chain!
    
    current_chain_offset = self.current_calculated_offset
    current_chain_time = Time.now
    
    # All actions that haven't finished yet
    pending = discourse_size_actions.where(action_type: ["grow", "shrink", "set_size"])
                                     .where("end_time > ?", current_chain_time)
                                     .order(created_at: :asc)
    
    first_action = true
    pending.each do |action|
      # Only the FIRST action in the queue can be considered "in-progress"
      if first_action && action.start_time && action.start_time <= Time.now
        # We preserve the start point of the active action to avoid jumping
        # but ensure the end point is still correctly offset from the start
        action.end_offset = action.start_offset + action.size_change
        action.end_time = action.start_time + action.duration_minutes.minutes
        first_action = false
      else
        # Future actions are stacked sequentially
        action.start_offset = current_chain_offset
        action.end_offset = action.start_offset + action.size_change
        action.start_time = current_chain_time
        action.end_time = action.start_time + action.duration_minutes.minutes
      end
      
      # Instant actions
      if action.duration_minutes <= 0
        action.end_time = action.start_time
      end

      action.save!
      
      current_chain_offset = action.end_offset
      current_chain_time = action.end_time
    end
    
    self.target_offset = current_chain_offset
    save!
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
#  folder_id            :bigint
#  user_id              :bigint           not null
#
# Indexes
#
#  index_discourse_size_characters_on_blocked_item_keys    (blocked_item_keys) USING gin
#  index_discourse_size_characters_on_blocked_user_ids     (blocked_user_ids) USING gin
#  index_discourse_size_characters_on_folder_id            (folder_id)
#  index_discourse_size_characters_on_user_id              (user_id)
#  index_discourse_size_characters_on_user_id_and_is_main  (user_id,is_main) UNIQUE WHERE (is_main = true)
#
