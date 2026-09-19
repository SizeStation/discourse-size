# frozen_string_literal: true

require "rails_helper"

describe DiscourseSize::TriggerExecutor do
  fab!(:user)
  fab!(:character) { Fabricate(:discourse_size_character, user: user, base_size: 170.0) }

  before do
    freeze_time Time.zone.now.change(usec: 0)
    SiteSetting.discourse_size_enabled = true
  end

  def execute_script(script)
    trigger = character.discourse_size_character_triggers.create!(name: "Resize", js_code: script)
    described_class.execute(character, trigger.name, user)
  ensure
    trigger&.destroy!
  end

  describe ".execute" do
    it "grows from the minimum using absolute endpoints even when legacy offsets are equal" do
      minimum = DiscourseSizeCharacter::MIN_SIZE
      expect(execute_script("character.setSize(#{minimum});")[:success]).to eq(true)

      result = execute_script("character.grow(#{minimum}, 60);")

      expect(result[:success]).to eq(true)
      action = character.discourse_size_actions.where(action_type: "grow").sole
      expect(action).to have_attributes(
        start_size: minimum,
        end_size: minimum * 2,
        size_change: minimum,
        start_offset: minimum - character.base_size,
        end_offset: minimum * 2 - character.base_size,
      )
      expect(character.reload.current_size).to eq(minimum)
      expect(character.target_size).to eq(minimum * 2)
      freeze_time 30.seconds.from_now
      expect(character.current_size).to be_within(minimum * 1e-12).of(minimum * 1.5)
    end

    it "preserves a huge-to-tiny instant target when later growth rebuilds the chain" do
      huge = DiscourseSizeCharacter::MAX_SIZE
      tiny = 1e-25
      expect(execute_script("character.setSize(#{huge});")[:success]).to eq(true)

      result = execute_script("character.setSize(#{tiny});")

      expect(result[:success]).to eq(true)
      action = character.discourse_size_actions.where(action_type: "set_size").order(:id).last
      expect(action).to have_attributes(
        start_size: huge,
        end_size: tiny,
        size_change: tiny - huge,
        start_offset: huge - character.base_size,
        end_offset: tiny - character.base_size,
      )
      expect(character.reload.current_size).to eq(tiny)

      expect(execute_script("character.grow(#{tiny}, 60);")[:success]).to eq(true)

      expect(action.reload.end_size).to eq(tiny)
      expect(character.reload.current_size).to eq(tiny)
      expect(character.target_size).to eq(tiny * 2)
    end

    it "queues absolute set-size targets and reports their precise progress endpoints" do
      huge = DiscourseSizeCharacter::MAX_SIZE
      tiny = 1e-25
      expect(execute_script("character.setSize(#{huge});")[:success]).to eq(true)

      result =
        execute_script(
          "character.setSize(#{tiny}, 60); character.queueSizeAnimation(#{tiny * 2}, 60);",
        )

      expect(result[:success]).to eq(true)
      actions = character.discourse_size_actions.where(action_type: "set_size").order(:id)
      expect(actions.pluck(:end_size)).to eq([huge, tiny, tiny * 2])
      expect(character.reload.target_size).to eq(tiny * 2)
      freeze_time 60.seconds.from_now
      progress = execute_script("character.getSizeProgress();")

      expect(character.current_size).to eq(tiny)
      expect(progress[:result]).to include(
        "active" => true,
        "start_value" => tiny,
        "end_value" => tiny * 2,
        "time_remaining_seconds" => 60,
      )
    end

    it "leaves numeric property animation offsets independent of height endpoints" do
      property =
        character.discourse_size_character_properties.create!(
          name: "Strength",
          property_type: "number",
          value: "10",
        )

      result =
        execute_script('character.setSize(1e-25); character.setProperty("Strength", 20, 60);')

      expect(result[:success]).to eq(true)
      action = character.discourse_size_actions.where(action_type: "property_change").sole
      expect(action).to have_attributes(
        start_offset: 10.0,
        end_offset: 20.0,
        start_size: nil,
        end_size: nil,
        size_change: 0.0,
      )
      freeze_time 30.seconds.from_now
      expect(property.reload.effective_value.to_f).to eq(15.0)
      expect(character.reload.current_size).to eq(1e-25)
    end

    it "cancels active and queued height animations at the current absolute size" do
      tiny = 1e-25
      expect(execute_script("character.setSize(#{tiny});")[:success]).to eq(true)
      expect(
        execute_script("character.grow(#{tiny}, 60); character.grow(#{tiny}, 60);")[:success],
      ).to eq(true)
      freeze_time 30.seconds.from_now
      current_size = character.current_size

      result = execute_script("character.cancelSizeAnimation(); character.size();")

      expect(result).to include(success: true, result: current_size)
      expect(character.reload.current_size).to eq(current_size)
      expect(character.target_size).to eq(current_size)
      expect(character.discourse_size_actions.where("end_time > ?", Time.current)).to be_empty
      freeze_time 2.minutes.from_now
      expect(character.current_size).to eq(current_size)

      expect(execute_script("character.grow(#{tiny}, 60);")[:success]).to eq(true)
      action = character.discourse_size_actions.where(action_type: "grow").sole
      expect(action.start_size).to eq(current_size)
      expect(character.reload.current_size).to eq(current_size)
      expect(character.target_size).to eq(current_size + tiny)
    end

    it "keeps the running height animation when a cancellation script fails" do
      expect(execute_script("character.grow(100, 60);")[:success]).to eq(true)
      freeze_time 30.seconds.from_now
      current_size = character.current_size
      target_size = character.target_size

      result = execute_script('character.cancelSizeAnimation(); throw new Error("Failed");')

      expect(result[:success]).to eq(false)
      expect(character.reload.current_size).to eq(current_size)
      expect(character.target_size).to eq(target_size)
      freeze_time 30.seconds.from_now
      expect(character.current_size).to eq(target_size)
    end

    it "allows normal characters to set sizes below MIN_SIZE or to Infinity via triggers" do
      character.update!(character_type: DiscourseSizeCharacter::TYPE_NORMAL)

      res_sub = execute_script("character.setSize(1e-40);")
      expect(res_sub[:success]).to eq(true)
      expect(character.reload.current_size).to eq(1e-40)

      res_inf = execute_script("character.setSize(Infinity);")
      expect(res_inf[:success]).to eq(true)
      expect(character.reload.current_size).to eq(Float::INFINITY)
      expect(character.reload.target_size).to eq(Float::INFINITY)
    end
  end
end
