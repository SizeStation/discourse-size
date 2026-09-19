# frozen_string_literal: true

require "mini_racer"

module ::DiscourseSize
  class TriggerExecutor
    def self.execute(character, trigger_name, actor)
      result = nil
      InventoryManager.with_character_locks([character.id]) do
        character.with_lock do
          result = execute_locked(character, trigger_name, actor)
          raise ActiveRecord::Rollback unless result[:success]
        end
      end
      result
    end

    def self.execute_locked(character, trigger_name, actor)
      trigger = character.discourse_size_character_triggers.find_by(name: trigger_name)
      return { success: false, error: "Trigger not found" } unless trigger

      # Finalize any expired property animations so the trigger script reads current values
      character
        .discourse_size_actions
        .where(action_type: "property_change")
        .where("end_time <= ?", Time.now)
        .where.not(end_time: nil)
        .find_each do |action|
          prop = character.discourse_size_character_properties.find_by(name: action.item_key)
          next unless prop
          prop.update_column(:value, action.end_offset.to_s) if prop.value != action.end_offset.to_s
        end

      context = MiniRacer::Context.new(timeout: 5000)

      # Track side effects — all created as child actions of the trigger action.
      # Use a local Hash so concurrent executions don't share state.
      state = {
        new_size: nil, # absolute target cm (instant)
        size_animations: [], # [{ action_type:, target_size:|target_delta:, duration_minutes: }]
        property_changes: {
        }, # { name => value } (instant)
        property_animations: [], # [{ name:, start_value:, end_value:, duration_seconds: }]
      }

      context.attach("character.size", -> { state[:new_size] || character.current_size })

      context.attach(
        "character.setSize",
        ->(new_size, duration_seconds = nil) do
          parsed = DiscourseSizeCharacter.parse_size(new_size)
          if duration_seconds && duration_seconds.to_f > 0
            state[:size_animations] << {
              action_type: "set_size",
              target_size: parsed,
              duration_minutes: duration_seconds.to_f / 60.0,
            }
          else
            state[:new_size] = parsed
          end
        end,
      )

      context.attach(
        "character.queueSizeAnimation",
        ->(target_cm, duration_seconds) do
          state[:size_animations] << {
            action_type: "set_size",
            target_size: DiscourseSizeCharacter.parse_size(target_cm),
            duration_minutes: duration_seconds.to_f / 60.0,
          }
        end,
      )

      context.attach(
        "character.grow",
        ->(amount, duration_seconds = 0) do
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
        end,
      )

      context.attach(
        "character.shrink",
        ->(amount, duration_seconds = 0) do
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
        end,
      )

      context.attach(
        "character.property",
        ->(name) do
          prop = character.discourse_size_character_properties.find_by(name: name)
          prop&.effective_value
        end,
      )

      context.attach(
        "character.setProperty",
        ->(name, value, duration_seconds = nil) do
          existing_prop = character.discourse_size_character_properties.find_by(name: name)
          raise "Property '#{name}' not found on character." unless existing_prop
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
        end,
      )

      context.attach(
        "character.queuePropertyAnimation",
        ->(name, value, duration_seconds) do
          existing_prop = character.discourse_size_character_properties.find_by(name: name)
          raise "Property '#{name}' not found on character." unless existing_prop
          start_val = existing_prop.effective_value
          state[:property_animations] << {
            name: name,
            start_value: start_val,
            end_value: value.to_s,
            duration_seconds: duration_seconds.to_f,
          }
        end,
      )

      context.attach("character.species", -> { character.species })

      context.attach("inchesToCm", ->(inches) { inches.to_f * 2.54 })
      context.attach("feetToCm", ->(feet) { feet.to_f * 30.48 })
      context.attach(
        "feetAndInchesToCm",
        ->(feet, inches) { feet.to_f * 30.48 + inches.to_f * 2.54 },
      )
      context.attach("milesToCm", ->(miles) { miles.to_f * 160934.4 })
      context.attach("character.age", -> { character.age })
      context.attach("character.pronouns", -> { character.pronouns })

      context.attach("user.points", -> { DiscourseSize::PointsManager.get_points(actor) })

      # Progress / cancellation helpers
      context.attach(
        "character.getSizeProgress",
        -> do
          next { active: false } if state[:new_size]

          active =
            character
              .discourse_size_actions
              .where(action_type: %w[grow shrink set_size])
              .where("start_time <= ? AND end_time > ?", Time.now, Time.now)
              .order(created_at: :desc)
              .first
          if active
            remaining = [(active.end_time - Time.now).to_f, 0.0].max
            {
              active: true,
              start_value: active.start_total_size,
              end_value: active.end_total_size,
              time_remaining_seconds: remaining,
            }
          else
            { active: false }
          end
        end,
      )

      context.attach(
        "character.getPropertyProgress",
        ->(name) do
          active =
            character
              .discourse_size_actions
              .where(action_type: "property_change", item_key: name)
              .where("start_time <= ? AND end_time > ?", Time.now, Time.now)
              .order(created_at: :desc)
              .first
          if active
            remaining = [(active.end_time - Time.now).to_f, 0.0].max
            {
              active: true,
              start_value: active.start_offset.to_f,
              end_value: active.end_offset.to_f,
              time_remaining_seconds: remaining,
            }
          else
            { active: false }
          end
        end,
      )

      context.attach(
        "character.cancelSizeAnimation",
        -> do
          # Persist the interpolated size as an absolute action after the script succeeds.
          state[:new_size] ||= character.current_size
          state[:size_animations].clear
        end,
      )

      context.attach(
        "character.cancelPropertyAnimation",
        ->(name) do
          prop_actions =
            character
              .discourse_size_actions
              .where(action_type: "property_change", item_key: name)
              .where("end_time > ?", Time.now)
          active = prop_actions.where("start_time <= ?", Time.now).first
          if active
            total = active.end_time - active.start_time
            if total > 0
              progress = (Time.now - active.start_time) / total
              current_val =
                active.start_offset + (active.end_offset - active.start_offset) * progress
              prop = character.discourse_size_character_properties.find_by(name: name)
              prop&.update_column(:value, current_val.to_s)
            end
          end
          prop_actions.destroy_all
        end,
      )

      begin
        result = context.eval(trigger.js_code)

        # Apply instant size change (setSize, grow, shrink without duration)
        start_size = state[:new_size] ? character.current_size : character.target_size
        end_size = start_size

        if state[:new_size]
          end_size =
            if state[:new_size].is_a?(Numeric)
              state[:new_size]
            else
              DiscourseSizeCharacter.parse_size(state[:new_size])
            end
          character
            .discourse_size_actions
            .where(action_type: %w[grow shrink set_size])
            .where("end_time > ?", Time.now)
            .destroy_all
        end

        size_change = (end_size.infinite? || start_size.infinite?) ? 0.0 : (end_size - start_size)
        start_offset =
          (
            if (start_size.infinite? || character.base_size&.infinite?)
              0.0
            else
              (start_size - character.base_size)
            end
          )
        end_offset =
          (
            if (end_size.infinite? || character.base_size&.infinite?)
              0.0
            else
              (end_size - character.base_size)
            end
          )

        # Apply instant property changes
        state[:property_changes].each do |name, value|
          prop = character.discourse_size_character_properties.find_by(name: name)
          raise "Property '#{name}' not found on character." unless prop
          prop.value = value
          prop.save!
        end

        # Create the trigger action — single activity entry for everything
        trigger_action =
          DiscourseSizeAction.create!(
            character_id: character.id,
            user_id: actor.id,
            action_type: "trigger",
            size_change: size_change,
            start_size: state[:new_size] ? start_size : nil,
            end_size: state[:new_size] ? end_size : nil,
            start_offset: start_offset,
            end_offset: end_offset,
            item_key: trigger.name,
            start_time: Time.now,
            end_time: Time.now,
          )

        if state[:new_size]
          DiscourseSizeAction.create!(
            character_id: character.id,
            user_id: actor.id,
            action_type: "set_size",
            size_change: size_change,
            start_size: start_size,
            end_size: end_size,
            start_offset: start_offset,
            end_offset: end_offset,
            duration_minutes: 0,
            start_time: Time.now,
            end_time: Time.now,
            parent_action_id: trigger_action.id,
          )
        end

        # Create child actions for animated size changes
        state[:size_animations].each do |anim|
          existing =
            character
              .discourse_size_actions
              .where(action_type: %w[grow shrink set_size])
              .where("end_time > ?", Time.now)
              .order(end_time: :desc)
              .first

          start_time = existing ? existing.end_time : Time.now
          animation_start_size = existing ? existing.end_total_size : character.current_size
          animation_end_size =
            if anim.key?(:target_size)
              anim[:target_size]
            else
              animation_start_size + anim[:target_delta]
            end

          anim_size_change =
            (
              if (animation_end_size.infinite? || animation_start_size.infinite?)
                0.0
              else
                (animation_end_size - animation_start_size)
              end
            )
          anim_start_offset =
            (
              if (animation_start_size.infinite? || character.base_size&.infinite?)
                0.0
              else
                (animation_start_size - character.base_size)
              end
            )
          anim_end_offset =
            (
              if (animation_end_size.infinite? || character.base_size&.infinite?)
                0.0
              else
                (animation_end_size - character.base_size)
              end
            )

          DiscourseSizeAction.create!(
            character_id: character.id,
            user_id: actor.id,
            action_type: anim[:action_type],
            size_change: anim_size_change,
            start_size: animation_start_size,
            end_size: animation_end_size,
            start_offset: anim_start_offset,
            end_offset: anim_end_offset,
            duration_minutes: anim[:duration_minutes],
            start_time: start_time,
            end_time: start_time + anim[:duration_minutes].minutes,
            parent_action_id: trigger_action.id,
          )
        end

        # Create child actions for animated property changes
        state[:property_animations].each do |anim|
          existing =
            character
              .discourse_size_actions
              .where(action_type: "property_change", item_key: anim[:name])
              .where("end_time > ?", Time.now)
              .order(end_time: :desc)
              .first

          start_time = existing ? existing.end_time : Time.now
          intended_start = anim[:start_value].to_f
          intended_end = anim[:end_value].to_f
          start_val = existing ? existing.end_offset.to_f : intended_start
          if intended_start > 0
            ratio = intended_end / intended_start
            end_val = start_val * ratio
          else
            diff = intended_end - intended_start
            end_val = start_val + diff
          end
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
            parent_action_id: trigger_action.id,
          )
        end

        if state[:size_animations].any?
          first_action =
            trigger_action
              .child_actions
              .where(action_type: %w[grow shrink set_size])
              .order(:created_at, :id)
              .first
          character.recalculate_pending_actions!(from_action: first_action)
        elsif state[:new_size]
          character.update!(
            current_offset: end_offset,
            target_offset: end_offset,
            start_offset: end_offset,
            offset_updated_at: Time.now,
          )
        end

        character.recalculate_properties! if state[:property_animations].any?

        { success: true, result: result }
      rescue MiniRacer::Error => e
        { success: false, error: "JS Error: #{e.message}" }
      end
    end
    private_class_method :execute_locked
  end
end
