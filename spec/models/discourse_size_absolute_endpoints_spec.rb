# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseSizeCharacter do
  fab!(:user)
  fab!(:character) do
    Fabricate(:discourse_size_character, user: user, base_size: 100.0, character_type: "game")
  end

  before { freeze_time Time.zone.now.change(usec: 0) }

  def apply_effect(effect, amount, duration: 0)
    character.add_queued_action(
      action_type: effect == "static" ? "set_size" : effect,
      effect_type: effect,
      effect_amount: amount,
      size_change: 0,
      duration_minutes: duration,
      user_id: user.id,
    ).fetch(:action)
  end

  describe "#add_queued_action" do
    it "stores five sequential absolute endpoints without rewriting the prefix or using the animated size" do
      first = apply_effect("grow", 50, duration: 10)
      original_first = first.attributes
      actions = [first]
      actions << apply_effect("shrink", 20, duration: 10)
      actions << apply_effect("grow", 100, duration: 10)
      actions << apply_effect("static", 80, duration: 10)
      actions << apply_effect("grow", 50, duration: 10)

      expect(
        actions.map { |action| [action.start_size, action.end_size, action.size_change] },
      ).to eq([[100, 150, 50], [150, 120, -30], [120, 240, 120], [240, 80, -160], [80, 120, 40]])
      expect(first.reload.attributes).to eq(original_first)
      expect(character.current_size).to eq(100)
      expect(character.target_size).to eq(120)
      expect(character.size_at(50.minutes.from_now)).to eq(120)
    end

    it "shrinks through the former float plateau down to the minimum and grows back out" do
      expected = character.base_size
      300.times do
        action = apply_effect("shrink", 25)
        expected = [expected * 0.75, described_class::MIN_SIZE].max
        expect(action.end_size).to eq(expected)
      end

      expect(character.reload.current_size).to eq(described_class::MIN_SIZE)
      expect(character.no_size_change_reason(effect_type: "shrink", effect_amount: 25)).to eq(
        "minimum_size",
      )
      expect(character.no_size_change_reason(effect_type: "grow", effect_amount: 100)).to be_nil
      grown = apply_effect("grow", 100)
      expect(grown).to have_attributes(
        start_size: described_class::MIN_SIZE,
        end_size: described_class::MIN_SIZE * 2,
        size_change: described_class::MIN_SIZE,
      )
      expect(character.reload.current_size).to eq(described_class::MIN_SIZE * 2)
    end

    it "caps growth at the maximum while allowing subsequent shrinkage" do
      apply_effect("static", described_class::MAX_SIZE)
      capped = apply_effect("grow", 100)

      expect(capped.end_size).to eq(described_class::MAX_SIZE)
      expect(capped.size_change).to eq(0)
      expect(character.no_size_change_reason(effect_type: "grow", effect_amount: 50)).to eq(
        "maximum_size",
      )
      expect(character.no_size_change_reason(effect_type: "shrink", effect_amount: 50)).to be_nil
      shrunk = apply_effect("shrink", 50)
      expect(shrunk.end_size).to eq(described_class::MAX_SIZE / 2)
      expect(character.current_size).to eq(described_class::MAX_SIZE / 2)
    end

    it "preserves huge-to-tiny static endpoints through completion and replay" do
      apply_effect("static", described_class::MAX_SIZE)
      tiny = apply_effect("static", 1e-25, duration: 10)
      apply_effect("grow", 100, duration: 10)

      expect(character.size_at(tiny.end_time)).to eq(1e-25)
      expect(character.size_at(tiny.end_time + 5.minutes)).to be_within(1e-39).of(1.5e-25)
      character.rebuild_offset_chain!
      expect(tiny.reload.end_size).to eq(1e-25)
      expect(character.target_size).to eq(2e-25)
    end
  end

  describe "#recalculate_pending_actions!" do
    it "replays only the refunded suffix precisely and leaves the tiny prefix untouched" do
      prefix = apply_effect("static", 1e-25)
      middle = apply_effect("grow", 100)
      suffix = apply_effect("shrink", 25)
      original_prefix = prefix.attributes

      DiscourseSize::InventoryManager.refund_action(middle)

      expect(prefix.reload.attributes).to eq(original_prefix)
      expect(suffix.reload.start_size).to eq(1e-25)
      expect(suffix.end_size).to be_within(1e-40).of(7.5e-26)
      expect(character.reload.current_size).to eq(suffix.end_size)
      expect(character.target_size).to eq(suffix.end_size)
    end
  end

  describe "#update!" do
    it "replays percentages from the new base while preserving tiny absolute set-size anchors" do
      grown = apply_effect("grow", 100)
      character.update_size(1e-25, user)
      fixed = character.discourse_size_actions.order(:id).last
      suffix = apply_effect("grow", 100)

      character.update!(base_size: 200)

      expect(grown.reload).to have_attributes(start_size: 200, end_size: 400)
      expect(fixed.reload.end_size).to eq(1e-25)
      expect(suffix.reload).to have_attributes(start_size: 1e-25, end_size: 2e-25)
      expect(character.current_size).to eq(2e-25)
    end

    it "materializes legacy fixed endpoints against the old base before a base edit" do
      legacy =
        character.discourse_size_actions.create!(
          user: user,
          action_type: "set_size",
          size_change: 150,
          start_offset: 0,
          end_offset: 150,
          start_time: Time.current,
          end_time: Time.current,
        )

      character.update!(base_size: 200)

      expect(legacy.reload.end_size).to eq(250)
      expect(character.current_size).to eq(250)
    end
  end

  describe "#size_at" do
    it "uses absolute endpoints for interpolation and preserves legacy property semantics" do
      character.update_size(1e-25, user)
      start = Time.current
      action = apply_effect("grow", 100, duration: 10)
      character.discourse_size_actions.create!(
        user: user,
        action_type: "property_change",
        item_key: "Strength",
        size_change: 0,
        start_offset: 10,
        end_offset: 20,
        start_time: start,
        end_time: 10.minutes.from_now,
      )

      expect(action.start_offset).to eq(action.end_offset)
      expect(character.size_at(start)).to eq(1e-25)
      expect(character.size_at(start + 5.minutes)).to be_within(1e-39).of(1.5e-25)
      expect(character.size_at(start + 10.minutes)).to eq(2e-25)
      expect(character.size_at(start + 20.minutes)).to eq(2e-25)
    end
  end
end
