# frozen_string_literal: true

require "mini_racer"

module ::DiscourseSize
  class TriggerExecutor
    def self.execute(character, trigger_name, actor)
      trigger = character.discourse_size_character_triggers.find_by(name: trigger_name)
      return { success: false, error: "Trigger not found" } unless trigger

      # Finalize any expired property animations so the trigger script reads current values
      character.discourse_size_actions
        .where(action_type: "property_change")
        .where("end_time <= ?", Time.now)
        .where.not(end_time: nil)
        .find_each do |action|
          prop = character.discourse_size_character_properties.find_by(name: action.item_key)
          next unless prop
          prop.update_column(:value, action.end_offset.to_s) if prop.value != action.end_offset.to_s
        end

      context = MiniRacer::Context.new

      # Track side effects — all created as child actions of the trigger action.
      # Use a local Hash so concurrent executions don't share state.
      state = {
        new_size: nil,               # absolute target cm (instant)
        size_animations: [],         # [{ action_type:, target_offset:|target_delta:, duration_minutes: }]
        property_changes: {},        # { name => value } (instant)
        property_animations: [],     # [{ name:, start_value:, end_value:, duration_seconds: }]
      }

      context.attach("character.size", -> { character.current_size })

      context.attach("character.setSize", ->(new_size, duration_seconds = nil) {
        if duration_seconds
          character.sync_offset!
          state[:size_animations] << {
            action_type: "set_size",
            target_offset: new_size.to_f - character.base_size,
            duration_minutes: duration_seconds.to_f / 60.0,
          }
        else
          state[:new_size] = new_size.to_f
        end
      })

      context.attach("character.queueSizeAnimation", ->(target_cm, duration_seconds) {
        character.sync_offset!
        state[:size_animations] << {
          action_type: "set_size",
          target_offset: target_cm.to_f - character.base_size,
          duration_minutes: duration_seconds.to_f / 60.0,
        }
      })

      context.attach("character.grow", ->(amount, duration_seconds = 0) {
        if duration_seconds.to_f > 0
          state[:size_animations] << {
            action_type: "grow",
            target_delta: amount.to_f,
            duration_minutes: duration_seconds.to_f / 60.0,
          }
        else
          current = state[:new_size] || character.current_size
          state[:new_size] = current + amount.to_f
        end
      })

      context.attach("character.shrink", ->(amount, duration_seconds = 0) {
        if duration_seconds.to_f > 0
          state[:size_animations] << {
            action_type: "shrink",
            target_delta: -amount.to_f.abs,
            duration_minutes: duration_seconds.to_f / 60.0,
          }
        else
          current = state[:new_size] || character.current_size
          state[:new_size] = current - amount.to_f.abs
        end
      })

      context.attach("character.property", ->(name) {
        prop = character.discourse_size_character_properties.find_by(name: name)
        prop&.effective_value
      })

      context.attach("character.setProperty", ->(name, value, duration_seconds = nil) {
        existing_prop = character.discourse_size_character_properties.find_by(name: name)
        unless existing_prop
          raise "Property '#{name}' not found on character."
        end
        if duration_seconds
          start_val = existing_prop.effective_value
          state[:property_animations] << {
            name: name,
            start_value: start_val,
            end_value: value.to_s,
            duration_seconds: duration_seconds.to_f,
          }
        else
          state[:property_changes][name] = value.to_s
        end
      })

      context.attach("character.queuePropertyAnimation", ->(name, value, duration_seconds) {
        existing_prop = character.discourse_size_character_properties.find_by(name: name)
        unless existing_prop
          raise "Property '#{name}' not found on character."
        end
        start_val = existing_prop.effective_value
        state[:property_animations] << {
          name: name,
          start_value: start_val,
          end_value: value.to_s,
          duration_seconds: duration_seconds.to_f,
        }
      })

      context.attach("character.species", -> { character.species })

      context.attach("inchesToCm", ->(inches) { inches.to_f * 2.54 })
      context.attach("feetToCm", ->(feet) { feet.to_f * 30.48 })
      context.attach("feetAndInchesToCm", ->(feet, inches) { feet.to_f * 30.48 + inches.to_f * 2.54 })
      context.attach("milesToCm", ->(miles) { miles.to_f * 160934.4 })
      context.attach("character.age", -> { character.age })
      context.attach("character.pronouns", -> { character.pronouns })

      context.attach("user.points", -> {
        DiscourseSize::PointsManager.get_points(actor)
      })

      # Progress / cancellation helpers
      context.attach("character.getSizeProgress", -> {
        active = character.discourse_size_actions
          .where(action_type: ["grow", "shrink", "set_size"])
          .where("start_time <= ? AND end_time > ?", Time.now, Time.now)
          .order(created_at: :desc)
          .first
        if active
          remaining = [(active.end_time - Time.now).to_f, 0.0].max
          { active: true, start_value: active.start_offset.to_f + character.base_size, end_value: active.end_offset.to_f + character.base_size, time_remaining_seconds: remaining }
        else
          { active: false }
        end
      })

      context.attach("character.getPropertyProgress", ->(name) {
        active = character.discourse_size_actions
          .where(action_type: "property_change", item_key: name)
          .where("start_time <= ? AND end_time > ?", Time.now, Time.now)
          .order(created_at: :desc)
          .first
        if active
          remaining = [(active.end_time - Time.now).to_f, 0.0].max
          { active: true, start_value: active.start_offset.to_f, end_value: active.end_offset.to_f, time_remaining_seconds: remaining }
        else
          { active: false }
        end
      })

      context.attach("character.cancelSizeAnimation", -> {
        size_actions = character.discourse_size_actions
          .where(action_type: ["grow", "shrink", "set_size"])
          .where("end_time > ?", Time.now)
        active = size_actions.where("start_time <= ?", Time.now).first
        if active
          total = active.end_time - active.start_time
          if total > 0
            progress = (Time.now - active.start_time) / total
            current_off = active.start_offset + (active.end_offset - active.start_offset) * progress
            character.current_offset = current_off
            character.target_offset = current_off
            character.start_offset = current_off
            character.offset_updated_at = Time.now
            character.save!
          end
        end
        size_actions.destroy_all
      })

      context.attach("character.cancelPropertyAnimation", ->(name) {
        prop_actions = character.discourse_size_actions
          .where(action_type: "property_change", item_key: name)
          .where("end_time > ?", Time.now)
        active = prop_actions.where("start_time <= ?", Time.now).first
        if active
          total = active.end_time - active.start_time
          if total > 0
            progress = (Time.now - active.start_time) / total
            current_val = active.start_offset + (active.end_offset - active.start_offset) * progress
            prop = character.discourse_size_character_properties.find_by(name: name)
            prop&.update_column(:value, current_val.to_s)
          end
        end
        prop_actions.destroy_all
      })

      begin
        result = context.eval(trigger.js_code)

        # Apply instant size change (setSize, grow, shrink without duration)
        old_target_offset = character.target_offset
        size_change = 0
        end_offset = 0

        if state[:new_size]
          character.sync_offset!
          new_total_cm = state[:new_size].to_f
          new_total_cm = 1e-18 if new_total_cm < 1e-18
          new_total_cm = DiscourseSizeCharacter::MAX_SIZE if new_total_cm > DiscourseSizeCharacter::MAX_SIZE

          old_target_offset = character.target_offset
          new_off = new_total_cm - character.base_size
          size_change = new_off - old_target_offset
          end_offset = new_off

          character.current_offset = new_off
          character.target_offset = new_off
          character.start_offset = new_off
          character.offset_updated_at = Time.now
          character.save!
        end

        # Apply instant property changes
        state[:property_changes].each do |name, value|
          prop = character.discourse_size_character_properties.find_by(name: name)
          raise "Property '#{name}' not found on character." unless prop
          prop.value = value
          prop.save!
        end

        # Create the trigger action — single activity entry for everything
        trigger_action = DiscourseSizeAction.create!(
          character_id: character.id,
          user_id: actor.id,
          action_type: "trigger",
          size_change: size_change,
          start_offset: old_target_offset,
          end_offset: end_offset,
          item_key: trigger.name,
          start_time: Time.now,
          end_time: Time.now
        )

        # Create child actions for animated size changes
        state[:size_animations].each do |anim|
          existing = character.discourse_size_actions
            .where(action_type: ["grow", "shrink", "set_size"])
            .where("end_time > ?", Time.now)
            .order(end_time: :desc)
            .first

          start_time = existing ? existing.end_time : Time.now
          base_off = existing ? existing.end_offset.to_f : character.current_calculated_offset

          if anim.key?(:target_offset)
            # setSize — use absolute target
            end_off = anim[:target_offset]
          else
            # grow/shrink — use delta from baseline
            end_off = base_off + anim[:target_delta]
          end

          DiscourseSizeAction.create!(
            character_id: character.id,
            user_id: actor.id,
            action_type: anim[:action_type],
            size_change: end_off - base_off,
            start_offset: base_off,
            end_offset: end_off,
            duration_minutes: anim[:duration_minutes],
            start_time: start_time,
            end_time: start_time + anim[:duration_minutes].minutes,
            parent_action_id: trigger_action.id
          )
        end

        # Create child actions for animated property changes
        state[:property_animations].each do |anim|
          existing = character.discourse_size_actions
            .where(action_type: "property_change", item_key: anim[:name])
            .where("end_time > ?", Time.now)
            .order(end_time: :desc)
            .first

          start_time = existing ? existing.end_time : Time.now
          intended_start = anim[:start_value].to_f
          intended_end = anim[:end_value].to_f
          ratio = intended_start > 0 ? intended_end / intended_start : 1.0
          start_val = existing ? existing.end_offset.to_f : intended_start
          end_val = start_val * ratio
          end_time = start_time + anim[:duration_seconds].seconds

          DiscourseSizeAction.create!(
            character_id: character.id,
            user_id: actor.id,
            action_type: "property_change",
            size_change: 0,
            item_key: anim[:name],
            start_offset: start_val,
            end_offset: end_val,
            duration_minutes: anim[:duration_seconds] / 60.0,
            start_time: start_time,
            end_time: end_time,
            parent_action_id: trigger_action.id
          )
        end

        { success: true, result: result }
      rescue MiniRacer::Error => e
        { success: false, error: "JS Error: #{e.message}" }
      end
    end
  end
end
