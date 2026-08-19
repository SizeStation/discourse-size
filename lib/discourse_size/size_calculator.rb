# frozen_string_literal: true

module DiscourseSize
  class SizeCalculator
    def self.calculate_offset(character, time = Time.now)
      # Find all growth/shrink actions with valid times
      actions = character.discourse_size_actions
                 .where(action_type: ["grow", "shrink", "set_size"])
                 .where.not(start_time: nil)
                 .where.not(end_time: nil)
                 .order(start_time: :asc, id: :asc)
      
      return 0.0 if actions.empty?

      # Find the active action at this specific time
      active_action = actions.find do |a|
        a.start_time && a.end_time && a.start_time <= time && a.end_time > time
      end
      
      if active_action
        total_duration = active_action.end_time - active_action.start_time
        if total_duration > 0
          progress = (time - active_action.start_time) / total_duration
          start_off = active_action.start_offset.to_f
          end_off = active_action.end_offset.to_f
          return start_off + (end_off - start_off) * progress
        else
          return active_action.end_offset.to_f
        end
      end

      # Check if we are BEFORE the first action
      if actions.first.start_time > time
        return actions.first.start_offset.to_f
      end

      # Check if we are AFTER the last action
      if actions.last.end_time <= time
        return actions.last.end_offset.to_f
      end

      # We are in a gap between actions. The size should be the end_offset of the most recent past action.
      last_past_action = actions.reverse_each.find { |a| a.end_time <= time }
      return last_past_action.end_offset.to_f if last_past_action

      0.0
    end

    def self.calculate_size(character, time = Time.now)
      character.base_size + calculate_offset(character, time)
    end
  end
end
