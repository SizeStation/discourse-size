# frozen_string_literal: true

class UserSizeStat < ActiveRecord::Base
  belongs_to :user

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

    # Amount of growth/shrinkage that could have happened
    change_amount = days_lapsed * growth_rate.abs

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
end
