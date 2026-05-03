# frozen_string_literal: true

module DiscourseSize
  class PointsManager
    CUSTOM_FIELD = "discourse_size_points"

    def self.get_points(user)
      user.custom_fields[CUSTOM_FIELD].to_i
    end

    def self.add_points(user, amount)
      return if amount == 0
      current = get_points(user)
      user.custom_fields[CUSTOM_FIELD] = current + amount
      user.save_custom_fields(true)
    end

    def self.remove_points(user, amount)
      return if amount == 0
      current = get_points(user)
      new_amount = [current - amount, 0].max
      user.custom_fields[CUSTOM_FIELD] = new_amount
      user.save_custom_fields(true)
    end

    def self.set_points(user, amount)
      amount = [amount, 0].max
      user.custom_fields[CUSTOM_FIELD] = amount
      user.save_custom_fields(true)
    end
  end
end
