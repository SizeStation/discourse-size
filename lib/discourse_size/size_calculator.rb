# frozen_string_literal: true

module DiscourseSize
  class SizeCalculator
    def self.calculate_size(character, time = Time.now)
      actions =
        character
          .discourse_size_actions
          .where(action_type: %w[grow shrink set_size])
          .where.not(start_time: nil)
          .where.not(end_time: nil)
          .order(start_time: :asc, id: :asc)
          .to_a

      if actions.empty?
        return character.base_size.to_f if character.normal?
        return clamp_size(character.base_size)
      end

      active_action = actions.find { |action| action.start_time <= time && action.end_time > time }
      if active_action
        progress =
          (time - active_action.start_time) / (active_action.end_time - active_action.start_time)
        start_size = active_action.start_total_size(character.base_size)
        end_size = active_action.end_total_size(character.base_size)
        return Float::INFINITY if start_size.infinite? || end_size.infinite?
        # Subtracting endpoints first can erase a tiny destination when shrinking.
        interpolated = (1 - progress) * start_size + progress * end_size
        return character.normal? ? interpolated : clamp_size(interpolated)
      end

      return actions.first.start_total_size(character.base_size) if actions.first.start_time > time

      last_past_action = actions.reverse_each.find { |action| action.end_time <= time }
      return last_past_action.end_total_size(character.base_size) if last_past_action

      character.normal? ? character.base_size.to_f : clamp_size(character.base_size)
    end

    def self.clamp_size(value)
      size = value.to_f
      return DiscourseSizeCharacter::MIN_SIZE unless size.finite?

      size.clamp(DiscourseSizeCharacter::MIN_SIZE, DiscourseSizeCharacter::MAX_SIZE)
    end

    # Compatibility cache only; never reconstruct authoritative sizes from this offset.
    def self.calculate_offset(character, time = Time.now)
      return 0.0 if character.base_size&.infinite?
      calculate_size(character, time) - character.base_size
    end
  end
end
