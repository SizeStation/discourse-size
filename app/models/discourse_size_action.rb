# frozen_string_literal: true

class DiscourseSizeAction < ActiveRecord::Base
  belongs_to :character, class_name: "DiscourseSizeCharacter"
  belongs_to :user
  
  belongs_to :parent_action, class_name: "DiscourseSizeAction", optional: true
  has_many :child_actions, class_name: "DiscourseSizeAction", foreign_key: :parent_action_id, dependent: :destroy

  before_destroy :revert_effects, if: -> { action_type == "trigger" }

  def revert_effects
    child_actions.each do |child|
      char = child.character
      next unless char

      if %w[set_size grow shrink].include?(child.action_type)
        char.sync_offset!
        off = child.start_offset.to_f
        char.current_offset = off
        char.target_offset = off
        char.start_offset = off
        char.offset_updated_at = Time.now
        char.save!
      elsif child.action_type == "property_change" && child.item_key.present?
        prop = char.discourse_size_character_properties.find_by(name: child.item_key)
        next unless prop
        prop.update_column(:value, child.start_offset.to_s)
      end
    end
  end

  validates :character_id, presence: true
  validates :user_id, presence: true
  validates :action_type,
            presence: true,
            inclusion: {
              in: %w[grow shrink reset boost_speed set_main unset_main set_size trigger property_change],
            }
  validates :size_change, presence: true

  def speed
    res = has_attribute?(:speed) ? read_attribute(:speed) : 1.0
    res.to_f > 0 ? res.to_f : 1.0
  end

  def speed=(val)
    write_attribute(:speed, val) if has_attribute?(:speed)
  end

  def start_offset
    has_attribute?(:start_offset) ? read_attribute(:start_offset) : nil
  end

  def start_offset=(val)
    write_attribute(:start_offset, val) if has_attribute?(:start_offset)
  end

  def end_offset
    has_attribute?(:end_offset) ? read_attribute(:end_offset) : nil
  end

  def end_offset=(val)
    write_attribute(:end_offset, val) if has_attribute?(:end_offset)
  end

  def item_key
    has_attribute?(:item_key) ? read_attribute(:item_key) : nil
  end

  def item_key=(val)
    write_attribute(:item_key, val) if has_attribute?(:item_key)
  end

  def duration_minutes
    has_attribute?(:duration_minutes) ? read_attribute(:duration_minutes) : 0
  end

  def duration_minutes=(val)
    write_attribute(:duration_minutes, val) if has_attribute?(:duration_minutes)
  end

  def start_time
    has_attribute?(:start_time) ? read_attribute(:start_time) : nil
  end

  def start_time=(val)
    write_attribute(:start_time, val) if has_attribute?(:start_time)
  end

  def end_time
    has_attribute?(:end_time) ? read_attribute(:end_time) : nil
  end

  def end_time=(val)
    write_attribute(:end_time, val) if has_attribute?(:end_time)
  end
end

# == Schema Information
#
# Table name: discourse_size_actions
#
#  id               :bigint           not null, primary key
#  action_type      :string           not null
#  duration_minutes :integer          default(0)
#  end_offset       :float
#  end_time         :datetime
#  item_key         :string
#  points_spent     :float            default(0.0), not null
#  size_change      :float            not null
#  speed            :float            default(1.0), not null
#  start_offset     :float
#  start_time       :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  character_id     :bigint           not null
#  notification_id  :bigint
#  parent_action_id :bigint
#  user_id          :bigint           not null
#
# Indexes
#
#  index_discourse_size_actions_on_character_id      (character_id)
#  index_discourse_size_actions_on_parent_action_id  (parent_action_id)
#
