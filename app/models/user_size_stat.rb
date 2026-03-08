# frozen_string_literal: true

class UserSizeStat < ActiveRecord::Base
  belongs_to :user

  before_validation :set_defaults, on: :create

  # Constants for measurement system
  MEASUREMENT_SYSTEMS = {
    system: 0,
    metric: 1,
    imperial: 2,
  }

  def current_size
    return target_size if base_size == target_size

    # Calculate time lapsed in days
    days_lapsed = (Time.zone.now - size_updated_at) / 1.day

    # Amount of growth/shrinkage that could have happened (percentage of base_size per day)
    change_amount = days_lapsed * (base_size * (growth_rate.abs / 100.0))

    total_difference = (target_size - base_size).abs

    if change_amount >= total_difference
      # We've reached or passed the target
      return target_size
    end

    if target_size > base_size
      base_size + change_amount
    else
      base_size - change_amount
    end
  end

  def dynamically_update_size!
    # If we reached the target size, or aren't there yet, this method
    # will cement the "current_size" as the new "base_size". This is useful
    # before applying new points/growth.
    new_base = current_size
    self.base_size = new_base
    self.size_updated_at = Time.zone.now
    save!
  end

  def update_default_size!(new_default)
    new_default = new_default.to_f
    return if new_default == default_size

    delta = new_default - default_size
    dynamically_update_size!
    
    self.default_size = new_default
    self.base_size = [self.base_size + delta, 0.000001].max
    self.target_size = [self.target_size + delta, 0.000001].max
    save!
  end

  def reset_size!
    self.default_size = [self.default_size, 0.000001].max
    self.base_size = self.default_size
    self.target_size = self.default_size
    self.size_updated_at = Time.zone.now
    save!
  end

  private

  def set_defaults
    self.size_updated_at ||= Time.zone.now
  end
end

# == Schema Information
#
# Table name: user_size_stats
#
#  id                  :bigint           not null, primary key
#  base_size           :float            default(170.0), not null
#  consent_grow        :boolean          default(FALSE), not null
#  consent_shrink      :boolean          default(FALSE), not null
#  default_size        :float            default(170.0), not null
#  growth_rate         :float            default(0.1), not null
#  measurement_system  :integer          default(0), not null
#  points              :integer          default(0), not null
#  ranking_public      :boolean          default(TRUE), not null
#  size_updated_at     :datetime         not null
#  target_size         :float            default(170.0), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  character_upload_id :integer
#  user_id             :integer          not null
#
# Indexes
#
#  index_user_size_stats_on_points       (points)
#  index_user_size_stats_on_target_size  (target_size)
#  index_user_size_stats_on_user_id      (user_id) UNIQUE
#
