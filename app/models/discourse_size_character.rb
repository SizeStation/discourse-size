# frozen_string_literal: true

class DiscourseSizeCharacter < ActiveRecord::Base
  belongs_to :user

  validates :name, presence: true
  validates :base_size,
            presence: true,
            numericality: {
              greater_than_or_equal_to: -> { SiteSetting.discourse_size_min_base_size },
              less_than_or_equal_to: -> { SiteSetting.discourse_size_max_base_size },
            }
  validates :user_id, presence: true

  has_many :discourse_size_actions,
           foreign_key: "character_id",
           dependent: :destroy

  def update_size_target(amount)
    sync_offset!
    new_target = self.target_offset + amount
    
    # Floor total size at a nanoscopic value (1e-18 cm) to prevent true zero/negative
    if (self.base_size + new_target) < 1e-18
      new_target = 1e-18 - self.base_size
    end
    
    self.target_offset = new_target
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

# == Schema Information
#
# Table name: discourse_size_characters
#
#  id                   :bigint           not null, primary key
#  allow_growth         :boolean          default(TRUE), not null
#  allow_shrink         :boolean          default(TRUE), not null
#  base_size            :float            not null
#  current_offset       :float            default(0.0), not null
#  growth_rate_override :float
#  info_post            :string
#  is_main              :boolean          default(FALSE), not null
#  measurement_system   :string           default("imperial"), not null
#  name                 :string           not null
#  offset_updated_at    :datetime         not null
#  picture              :string
#  target_offset        :float            default(0.0), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  user_id              :integer          not null
#
# Indexes
#
#  index_discourse_size_characters_on_user_id              (user_id)
#  index_discourse_size_characters_on_user_id_and_is_main  (user_id,is_main) UNIQUE WHERE (is_main = true)
#
