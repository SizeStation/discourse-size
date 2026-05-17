# frozen_string_literal: true

require "mini_racer"

module ::DiscourseSize
  class TriggerExecutor
    def self.execute(character, trigger_name, actor)
      trigger = character.discourse_size_character_triggers.find_by(name: trigger_name)
      return { success: false, error: "Trigger not found" } unless trigger

      context = MiniRacer::Context.new
      
      # Helper to track side effects
      @new_size = nil
      @size_duration_seconds = nil
      @property_changes = {}

      # character object
      context.attach("character.size", -> { character.current_size })
      context.attach("character.setSize", ->(new_size, duration_seconds = 0) {
        if duration_seconds.to_f > 0
          character.sync_offset!
          current_total = character.current_size
          size_change = new_size.to_f - current_total
          character.add_queued_action(
            action_type: "set_size",
            size_change: size_change,
            duration_minutes: duration_seconds.to_f / 60.0,
            user_id: actor.id,
            item_key: trigger.name
          )
          @new_size = nil
        else
          @new_size = new_size.to_f
        end
      })
      
      context.attach("character.grow", ->(amount, duration_seconds = 0) {
        character.add_queued_action(
          action_type: "grow",
          size_change: amount.to_f,
          duration_minutes: duration_seconds.to_f / 60.0,
          user_id: actor.id,
          item_key: trigger.name
        )
      })

      context.attach("character.shrink", ->(amount, duration_seconds = 0) {
        character.add_queued_action(
          action_type: "shrink",
          size_change: -amount.to_f.abs,
          duration_minutes: duration_seconds.to_f / 60.0,
          user_id: actor.id,
          item_key: trigger.name
        )
      })

      context.attach("character.property", ->(name) {
        prop = character.discourse_size_character_properties.find_by(name: name)
        prop&.value
      })
      
      context.attach("character.setProperty", ->(name, value) {
        @property_changes ||= {}
        @property_changes[name] = value.to_s
      })

      context.attach("character.species", -> { character.species })

      # unit conversion helpers (all size functions take centimeters)
      context.attach("inchesToCm", ->(inches) { inches.to_f * 2.54 })
      context.attach("feetToCm", ->(feet) { feet.to_f * 30.48 })
      context.attach("feetAndInchesToCm", ->(feet, inches) { feet.to_f * 30.48 + inches.to_f * 2.54 })
      context.attach("milesToCm", ->(miles) { miles.to_f * 160934.4 })
      context.attach("character.age", -> { character.age })
      context.attach("character.pronouns", -> { character.pronouns })

      # user object (read-only)
      context.attach("user.points", -> {
        DiscourseSize::PointsManager.get_points(actor)
      })

      begin
        result = context.eval(trigger.js_code)
        
        # Log the trigger execution
        DiscourseSizeAction.create!(
          character_id: character.id,
          user_id: actor.id,
          action_type: "trigger",
          size_change: 0,
          item_key: trigger.name,
          start_time: Time.now,
          end_time: Time.now
        )

        # Apply changes
        if @new_size
          character.update_size(@new_size, actor)
        end
        
        @property_changes.each do |name, value|
          prop = character.discourse_size_character_properties.find_or_initialize_by(name: name)
          prop.value = value
          prop.save!
        end

        { success: true, result: result }
      rescue MiniRacer::Error => e
        { success: false, error: "JS Error: #{e.message}" }
      end
    end
  end
end
