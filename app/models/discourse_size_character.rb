# frozen_string_literal: true

class DiscourseSizeCharacter < ActiveRecord::Base
  belongs_to :user

  validates :name, presence: true
  validates :base_size, presence: true
  validates :user_id, presence: true

  has_many :discourse_size_actions, foreign_key: 'character_id', dependent: :destroy

  def update_size_target(amount)
    sync_offset!
    self.target_offset += amount
    save!
  end

  def current_size
    base_size + current_calculated_offset
  end

  def current_calculated_offset
    # Calculate offset based on target_offset, current_offset, offset_updated_at, and max_growth_rate
    # If target_offset == current_offset, return current_offset
    return current_offset if target_offset == current_offset || offset_updated_at.nil?

    rate_cm_per_day = growth_rate_override || SiteSetting.discourse_size_default_max_growth_rate
    return target_offset if rate_cm_per_day <= 0

    rate_cm_per_sec = rate_cm_per_day / 86400.0
    seconds_elapsed = Time.now - offset_updated_at

    max_change = rate_cm_per_sec * seconds_elapsed

    if target_offset > current_offset
      new_offset = current_offset + max_change
      new_offset = target_offset if new_offset > target_offset
    else
      new_offset = current_offset - max_change
      new_offset = target_offset if new_offset < target_offset
    end

    new_offset
  end
  
  def sync_offset!
    new_offset = current_calculated_offset
    if new_offset != current_offset
      self.current_offset = new_offset
      self.offset_updated_at = Time.now
      self.save!
    end
  end

end
