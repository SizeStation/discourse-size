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
  before_update :adjust_offsets_on_base_size_change, if: :will_save_change_to_base_size?
  after_update :rebuild_offset_chain!, if: -> { game? && saved_change_to_base_size? }

  self.ignored_columns = %w[
    allow_growth
    allow_shrink
    growth_speed_multiplier
    measurement_system
    site_sink
  ]

  TYPE_GAME = "game"
  TYPE_NORMAL = "normal"

  MAX_SIZE = 1e120
  MIN_SIZE = 1e-35

  def set_default_position
    return if position.present?
    if folder_id.nil?
      max_char =
        DiscourseSizeCharacter.where(user_id: user_id, folder_id: nil).maximum(:position) || 0
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
    mapping.each { |id, position| where(id: id, user_id: user.id).update_all(position: position) }
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
  validates :base_size,
            numericality: {
              greater_than_or_equal_to: MIN_SIZE,
              less_than_or_equal_to: MAX_SIZE,
            },
            if: :normal?
  validates :user_id, presence: true

  has_many :discourse_size_actions, foreign_key: "character_id", dependent: :destroy

  validates :character_type, inclusion: { in: [TYPE_GAME, TYPE_NORMAL] }

  def game?
    character_type == TYPE_GAME
  end

  def normal?
    character_type == TYPE_NORMAL
  end

  def destroy_with_linked_effects!
    character_ids = [id]

    loop do
      character_ids |= linked_actions.distinct.pluck(:character_id)
      DiscourseSize::InventoryManager.with_character_locks(character_ids) do
        reload
        boundaries =
          linked_actions.to_a.group_by(&:character_id).transform_values do |actions|
            actions.min_by { |action| [action.created_at, action.id] }
          end
        next if (boundaries.keys - character_ids).any?

        self.class.transaction do
          destroy!
          self.class.where(id: boundaries.keys).find_each do |character|
            character.recalculate_pending_actions!(from_action: boundaries.fetch(character.id))
          end
        end
        return self
      end
    end
  end

  def update_size_target(amount)
    sync_offset!
    self.start_offset = self.current_offset
    self.offset_updated_at = Time.zone.now
    new_target = self.target_offset + amount

    new_target = MAX_SIZE - self.base_size if (self.base_size + new_target) > MAX_SIZE

    new_target = MIN_SIZE - self.base_size if (self.base_size + new_target) < MIN_SIZE

    self.target_offset = new_target
    save!
  end

  def update_size(new_total_cm, actor)
    new_total_cm = new_total_cm.to_f
    new_total_cm = MIN_SIZE if new_total_cm < MIN_SIZE
    new_total_cm = MAX_SIZE if new_total_cm > MAX_SIZE

    # Stop all pending growth/shrinking/set_size
    discourse_size_actions
      .where(action_type: %w[grow shrink set_size])
      .where("end_time > ?", Time.zone.now)
      .destroy_all

    old_target_offset = target_offset
    new_offset = new_total_cm - base_size
    size_change = new_offset - old_target_offset

    self.current_offset = new_offset
    self.target_offset = new_offset
    self.start_offset = new_offset
    self.offset_updated_at = Time.zone.now
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
      start_time: Time.zone.now,
      end_time: Time.zone.now,
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

  def is_max_size?
    current_size >= MAX_SIZE || (MAX_SIZE - current_size) / MAX_SIZE < 1e-12
  end

  def is_min_size?
    current_size <= MIN_SIZE || (current_size - MIN_SIZE) / MIN_SIZE < 1e-12
  end

  def time_remaining_seconds
    now = Time.zone.now
    active_action =
      discourse_size_actions
        .where(action_type: %w[grow shrink])
        .where("start_time <= ? AND end_time > ?", now, now)
        .first
    return 0 unless active_action

    (active_action.end_time - now).to_i
  end

  def sync_offset!
    new_offset = current_calculated_offset
    if new_offset != current_offset
      # update_columns: this just refreshes a derived cache value from the action
      # log, so it must not be blocked by unrelated validation failures (e.g. a
      # base_size that was valid under old bounds but no longer is).
      update_columns(current_offset: new_offset, offset_updated_at: Time.zone.now)
    end
  end

  def is_blocked?(user, item_key: nil, action_type: nil, amount: nil)
    return false if user.nil?
    return false if user.id == user_id # Owner is never blocked

    return true if blocked_user_ids&.map(&:to_i)&.include?(user.id.to_i)

    keys = blocked_item_keys || []

    return true if keys.include?("__all__")
    return true if item_key.present? && keys.include?(item_key)

    if item_key.present? && (action_type.nil? || (action_type == "static" && amount.nil?))
      item = DiscourseSizeShopItem.find_by(key: item_key)
      if item
        action_type ||= item.effect
        amount ||= item.amount
      end
    end

    effective_type = action_type
    if action_type == "static" && amount.present?
      current_total = base_size + target_offset
      if amount.to_f > current_total
        effective_type = "grow"
      elsif amount.to_f < current_total
        effective_type = "shrink"
      end
    end

    if effective_type == "grow"
      return true if keys.include?("__all_growing__")
      return true if keys.include?("__direct_grow__")
    elsif effective_type == "shrink"
      return true if keys.include?("__all_shrinking__")
      return true if keys.include?("__direct_shrink__")
    end

    false
  end

  def add_queued_action(
    action_type:,
    size_change:,
    duration_minutes:,
    user_id:,
    item_key: nil,
    parent_action_id: nil,
    effect_type: nil,
    effect_amount: nil
  )
    if effect_type.nil? && item_key.present?
      item = DiscourseSizeShopItem.find_by(key: item_key)
      if item
        self_effect = parent_action_id.present? && item.self_effect.present?
        effect_type = self_effect ? item.self_effect : item.effect
        effect_amount = self_effect ? item.self_amount.to_f : item.amount.to_f
      end
    end

    self.class.transaction do
      previous_action = ordered_size_actions.last
      start_offset = previous_action&.end_offset.to_f
      start_total = base_size + start_offset
      action =
        discourse_size_actions.build(
          user_id: user_id,
          action_type: action_type,
          size_change: size_change,
          points_spent: 0,
          item_key: item_key,
          parent_action_id: parent_action_id,
          effect_type: effect_type,
          effect_amount: effect_amount,
          duration_minutes: duration_minutes.to_f,
        )
      new_total = action.size_after_effect(start_total) || (start_total + size_change)
      capped_type = :max if new_total > MAX_SIZE
      capped_type = :min if new_total < MIN_SIZE
      new_total = new_total.clamp(MIN_SIZE, MAX_SIZE)
      start_time = [Time.zone.now, previous_action&.end_time].compact.max
      action.assign_attributes(
        start_offset: start_offset,
        end_offset: new_total - base_size,
        size_change: new_total - start_total,
        start_time: start_time,
        end_time: start_time + duration_minutes.to_f.minutes,
      )
      action.save!
      self.target_offset = action.end_offset
      save!
      sync_offset!

      { capped: capped_type, size_change: action.size_change, action: action }
    end
  end

  def rebuild_offset_chain!(from_action: nil)
    actions = ordered_size_actions
    current_chain_offset = 0.0
    if from_action
      previous_action =
        actions.where("(created_at, id) < (?, ?)", from_action.created_at, from_action.id).last
      current_chain_offset = previous_action&.end_offset.to_f
      actions =
        actions.where("(created_at, id) >= (?, ?)", from_action.created_at, from_action.id)
    end

    actions.each do |action|
      current_total = base_size + current_chain_offset
      new_total = action.size_after_effect(current_total)
      if new_total.nil?
        new_total =
          if action.action_type == "set_size" && action.end_offset.present?
            base_size + action.end_offset
          else
            current_total + action.size_change
          end
      end
      new_total = new_total.clamp(MIN_SIZE, MAX_SIZE)
      action.update!(
        size_change: new_total - current_total,
        start_offset: current_chain_offset,
        end_offset: new_total - base_size,
      )
      current_chain_offset = action.end_offset
    end

    self.target_offset = current_chain_offset
    save!
    sync_offset!
  end

  def recalculate_pending_actions!(from_action: nil)
    rebuild_offset_chain!(from_action: from_action)
    recalculate_properties!

    now = Time.zone.now
    pending = ordered_size_actions.where("end_time > ?", now)
    if from_action
      pending =
        pending.where("(created_at, id) >= (?, ?)", from_action.created_at, from_action.id)
    end

    if first_action = pending.first
      previous_action =
        ordered_size_actions
          .where("(created_at, id) < (?, ?)", first_action.created_at, first_action.id)
          .last
      chain_time = [now, previous_action&.end_time].compact.max
      pending.each_with_index do |action, index|
        unless index == 0 && action.start_time && action.start_time <= now && chain_time == now
          action.start_time = chain_time
        end
        action.end_time = action.start_time + action.duration_minutes.to_f.minutes
        action.save!
        chain_time = action.end_time
      end
    end

    sync_offset!
    self.start_offset = current_calculated_offset if pending.empty?
    save!
  end

  def recalculate_properties!
    discourse_size_character_properties.each do |prop|
      prop_actions =
        discourse_size_actions.where(action_type: "property_change", item_key: prop.name).order(
          created_at: :asc,
          id: :asc,
        )

      latest_expired = prop_actions.where("end_time <= ?", Time.zone.now).last
      if latest_expired
        prop.update_column(:value, latest_expired.end_offset.to_s)
      elsif prop_actions.any?
        prop.update_column(:value, prop_actions.first.start_offset.to_s)
      end
    end
  end

  private

  def ordered_size_actions
    discourse_size_actions.where(action_type: %w[grow shrink set_size]).order(
      created_at: :asc,
      id: :asc,
    )
  end

  def linked_actions
    DiscourseSizeAction
      .where(parent_action_id: discourse_size_actions.select(:id))
      .where.not(character_id: id)
  end

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
    DiscourseSizeCharacter
      .where(user_id: user_id, is_main: true)
      .where.not(id: id)
      .update_all(is_main: false)
  end

  def adjust_offsets_on_base_size_change
    return unless game?
    old_base, new_base = base_size_change_to_be_saved
    return if old_base.nil? || new_base.nil?

    delta = new_base - old_base
    return if delta.abs < 1e-40

    has_actions = discourse_size_actions.where(action_type: %w[grow shrink set_size]).exists?
    return if !has_actions && current_offset.to_f.abs < 1e-40 && target_offset.to_f.abs < 1e-40

    self.current_offset = current_offset.to_f - delta
    self.target_offset = target_offset.to_f - delta
    self.start_offset = start_offset.to_f - delta if respond_to?(:start_offset) &&
      start_offset.present?

    discourse_size_actions.where(action_type: %w[grow shrink set_size]).update_all(
      ["start_offset = start_offset - ?, end_offset = end_offset - ?", delta, delta],
    )
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
