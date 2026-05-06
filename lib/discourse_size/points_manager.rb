# frozen_string_literal: true

module ::DiscourseSize
  class PointsManager
    CUSTOM_FIELD = "discourse_size_points"

    def self.get_points(user)
      return 0 if user.nil? || !user.respond_to?(:custom_fields) || user.custom_fields.nil?
      user.custom_fields[CUSTOM_FIELD].to_i
    end

    def self.add_points(user, amount, source_type: "unknown", description: nil)
      return if user.nil? || amount.to_f <= 0
      current = get_points(user)
      user.custom_fields[CUSTOM_FIELD] = current + amount
      user.save_custom_fields(true)

      DiscourseSizePointHistory.create!(
        user_id: user.id,
        amount: amount,
        source_type: source_type,
        description: description
      )
    end

    def self.remove_points(user, amount, source_type: "unknown", description: nil)
      return if user.nil? || amount.to_f <= 0
      current = get_points(user)
      new_amount = [current - amount, 0].max
      actual_removed = current - new_amount
      
      user.custom_fields[CUSTOM_FIELD] = new_amount
      user.save_custom_fields(true)

      DiscourseSizePointHistory.create!(
        user_id: user.id,
        amount: -actual_removed,
        source_type: source_type,
        description: description
      )
    end

    def self.set_points(user, amount, description: "Admin correction")
      return if user.nil?
      amount = [amount.to_f, 0].max
      current = get_points(user)
      diff = amount - current
      return if diff == 0

      user.custom_fields[CUSTOM_FIELD] = amount
      user.save_custom_fields(true)

      DiscourseSizePointHistory.create!(
        user_id: user.id,
        amount: diff,
        source_type: "admin_correction",
        description: description
      )
    end
  end
end
