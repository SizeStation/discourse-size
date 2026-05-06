# frozen_string_literal: true

module DiscourseSize
  class SizeCalculator
    def self.calculate_offset(character, time = Time.now)
      # Find all growth/shrink actions
      actions = character.discourse_size_actions.where(action_type: ["grow", "shrink", "set_size"])
                 .order(start_time: :asc)
      
      return character.current_offset if actions.empty?

      # Find the active action at this specific time
      active_action = actions.find { |a| a.start_time <= time && a.end_time > time }
      
      if active_action
        total_duration = active_action.end_time - active_action.start_time
        if total_duration > 0
          progress = (time - active_action.start_time) / total_duration
          return active_action.start_offset + (active_action.end_offset - active_action.start_offset) * progress
        else
          return active_action.end_offset
        end
      end

      # Check if we are BEFORE the first action
      if actions.first.start_time > time
        return actions.first.start_offset
      end

      # Check if we are AFTER the last action
      if actions.last.end_time <= time
        return actions.last.end_offset
      end

      # We are in a gap between actions. The size should be the end_offset of the most recent past action.
      last_past_action = actions.reverse_each.find { |a| a.end_time <= time }
      return last_past_action.end_offset if last_past_action

      character.current_offset
    end

    def self.calculate_size(character, time = Time.now)
      character.base_size + calculate_offset(character, time)
    end
  end
end
