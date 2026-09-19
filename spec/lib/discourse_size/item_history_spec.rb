# frozen_string_literal: true

require "rails_helper"

describe DiscourseSize::InventoryManager do
  fab!(:user)
  fab!(:character) do
    Fabricate(
      :discourse_size_character,
      user: user,
      base_size: 100.0,
      character_type: DiscourseSizeCharacter::TYPE_GAME,
    )
  end

  before do
    freeze_time
    SiteSetting.discourse_size_enabled = true
  end

  def create_item(key, effect: "grow", amount: 50.0, duration_minutes: 0, **attributes)
    DiscourseSizeShopItem.create!(
      key: key,
      name: key.humanize,
      price: 0,
      effect: effect,
      amount: amount,
      duration_minutes: duration_minutes,
      uses: 1,
      **attributes,
    )
  end

  def use_item(item, target: character, actor: user)
    inventory = DiscourseSizeInventory.create!(user: actor, item_key: item.key, uses_remaining: 1)
    result = described_class.use_item(actor, inventory.id, target.id)
    expect(result[:success]).to eq(true), result.inspect
    target.discourse_size_actions.order(created_at: :desc, id: :desc).first
  end

  describe ".use_item" do
    it "rolls back both effects and preserves inventory when the self-effect character is invalid" do
      target =
        Fabricate(
          :discourse_size_character,
          base_size: 100.0,
          character_type: DiscourseSizeCharacter::TYPE_GAME,
        )
      character.update!(character_type: DiscourseSizeCharacter::TYPE_GAME, is_main: true)
      character.update_column(:name, "")
      item = create_item("invalid_paired_growth", self_effect: "grow", self_amount: 25.0)
      inventory = DiscourseSizeInventory.create!(user: user, item_key: item.key, uses_remaining: 1)
      original_characters = [target, character].map { |record| record.reload.attributes }
      original_inventory = inventory.attributes

      expect { described_class.use_item(user, inventory.id, target.id) }.to raise_error(
        ActiveRecord::RecordInvalid,
      ) { |error| expect(error.record).to eq(character) }

      expect(DiscourseSizeAction.where(character_id: [target.id, character.id])).to be_empty
      expect([target, character].map { |record| record.reload.attributes }).to eq(
        original_characters,
      )
      expect(inventory.reload.attributes).to eq(original_inventory)
    end

    it "appends from the last chronological endpoint without rewriting the existing queue" do
      item = create_item("append_growth", duration_minutes: 10)
      first = use_item(item)
      second = use_item(item)
      original_actions = [first, second].map { |action| action.reload.attributes }
      item.update!(amount: 75.0)
      character.update_columns(target_offset: 0.0)
      freeze_time 2.minutes.from_now

      appended = use_item(item)

      expect([first, second].map { |action| action.reload.attributes }).to eq(original_actions)
      expect(appended).to have_attributes(
        effect_type: "grow",
        effect_amount: 75.0,
        start_offset: 125.0,
        end_offset: 293.75,
        size_change: 168.75,
        start_time: second.end_time,
        end_time: second.end_time + 10.minutes,
      )
      expect(character.reload.target_offset).to eq(293.75)
    end

    it "keeps a 50 percent snapshot after a shop edit to 75 percent, a base edit, and a refund" do
      character.update!(character_type: DiscourseSizeCharacter::TYPE_GAME)
      item = create_item("editable_growth")
      first = use_item(item)
      original_first = first.reload.attributes
      item.update!(amount: 75.0)
      freeze_time 1.minute.from_now

      second = use_item(item)

      expect(first.reload.attributes).to eq(original_first)
      expect(second).to have_attributes(effect_amount: 75.0, end_offset: 162.5)

      character.reload.update!(base_size: 200.0)

      expect(first.reload).to have_attributes(
        effect_type: "grow",
        effect_amount: 50.0,
        start_offset: 0.0,
        end_offset: 100.0,
      )
      expect(second.reload).to have_attributes(start_offset: 100.0, end_offset: 325.0)
      expect(character.reload.current_size).to eq(525.0)

      described_class.refund_action(first)

      expect(second.reload).to have_attributes(
        effect_amount: 75.0,
        start_offset: 0.0,
        end_offset: 150.0,
      )
      expect(character.reload.current_size).to eq(350.0)
    end
  end

  describe ".refund_action" do
    it "rejects a second refund from a stale action without returning another inventory use" do
      item = create_item("single_refund_growth")
      action = use_item(item)
      stale_action = DiscourseSizeAction.find(action.id)

      described_class.refund_action(action)

      inventory = DiscourseSizeInventory.find_by!(user: user, item_key: item.key)
      expect(inventory.uses_remaining).to eq(1)
      expect { described_class.refund_action(stale_action) }.to raise_error(
        ActiveRecord::RecordNotFound,
      )
      expect(
        DiscourseSizeInventory.where(user: user, item_key: item.key).pluck(:id, :uses_remaining),
      ).to eq([[inventory.id, 1]])
      expect(character.reload.current_size).to eq(100.0)
    end

    it "replays 100 plus 100 percent plus 50 percent as 150 when the first item is refunded" do
      double = create_item("double_growth", amount: 100.0)
      half = create_item("half_growth")
      first = use_item(double)
      second = use_item(half)

      expect(character.reload).to be_game
      expect(first.reload.end_offset).to eq(100.0)
      expect(second.reload.end_offset).to eq(200.0)
      expect(character.current_size).to eq(300.0)

      described_class.refund_action(first)

      expect(DiscourseSizeAction.exists?(first.id)).to eq(false)
      expect(second.reload).to have_attributes(
        start_offset: 0.0,
        end_offset: 50.0,
        size_change: 50.0,
      )
      expect(character.reload.current_size).to eq(150.0)
      expect(character.target_offset).to eq(50.0)
      expect(
        DiscourseSizeInventory.where(user: user, item_key: double.key).sum(:uses_remaining),
      ).to eq(1)
    end

    it "preserves the prefix and reschedules only the suffix when refunding a middle action" do
      growth = create_item("queued_growth", duration_minutes: 10)
      shrink = create_item("queued_shrink", effect: "shrink", amount: 20.0, duration_minutes: 5)
      prefix = use_item(growth)
      middle = use_item(growth)
      suffix = use_item(shrink)
      original_prefix = prefix.reload.attributes
      expect([prefix, middle, suffix].map(&:created_at).uniq.size).to eq(1)
      expect(suffix.reload).to have_attributes(start_offset: 125.0, end_offset: 80.0)
      freeze_time 2.minutes.from_now

      described_class.refund_action(middle)

      expect(prefix.reload.attributes).to eq(original_prefix)
      expect(DiscourseSizeAction.exists?(middle.id)).to eq(false)
      expect(suffix.reload).to have_attributes(
        start_offset: 50.0,
        end_offset: 20.0,
        size_change: -30.0,
        start_time: prefix.end_time,
        end_time: prefix.end_time + 5.minutes,
      )
      expect(character.reload.target_offset).to eq(20.0)
    end

    it "restores the preceding endpoint for a last refund and the base for the final refund" do
      growth = create_item("last_growth")
      first = use_item(growth)
      last = use_item(growth)
      original_first = first.reload.attributes
      freeze_time 1.minute.from_now

      described_class.refund_action(last)

      expect(first.reload.attributes).to eq(original_first)
      expect(character.reload.current_size).to eq(150.0)
      expect(character.target_offset).to eq(50.0)

      described_class.refund_action(first)

      expect(character.discourse_size_actions).to be_empty
      expect(character.reload.current_size).to eq(100.0)
      expect(character.target_offset).to eq(0.0)
      expect(
        DiscourseSizeInventory.where(user: user, item_key: growth.key).sum(:uses_remaining),
      ).to eq(2)
    end

    it "replays completed percentages, an active shrink, and queued static and percentage effects" do
      double = create_item("completed_double", amount: 100.0)
      growth = create_item("completed_growth")
      shrink = create_item("active_shrink", effect: "shrink", amount: 20.0, duration_minutes: 10)
      static = create_item("queued_static", effect: "static", amount: 180.0, duration_minutes: 5)
      queued_growth = create_item("after_static_growth", duration_minutes: 10)
      first = use_item(double)
      completed = use_item(growth)
      active = use_item(shrink)
      fixed = use_item(static)
      queued = use_item(queued_growth)
      freeze_time 5.minutes.from_now

      expect(completed.reload.end_time).to be <= Time.current
      expect(active.reload.start_time).to be < Time.current
      expect(active.end_time).to be > Time.current
      expect(fixed.reload.start_time).to be > Time.current
      expect(character.reload.current_size).to be_within(1e-6).of(270.0)

      described_class.refund_action(first)

      expect(completed.reload).to have_attributes(start_offset: 0.0, end_offset: 50.0)
      expect(active.reload).to have_attributes(start_offset: 50.0, end_offset: 20.0)
      expect(fixed.reload).to have_attributes(
        effect_type: "static",
        effect_amount: 180.0,
        start_offset: 20.0,
        end_offset: 80.0,
        start_time: active.end_time,
      )
      expect(queued.reload).to have_attributes(
        start_offset: 80.0,
        end_offset: 170.0,
        start_time: fixed.end_time,
      )
      expect(character.reload.target_offset).to eq(170.0)
      expect(character.size_at(queued.end_time)).to eq(270.0)
    end

    it "uses unequal same-direction paired snapshots and refunds each character from its own prefix" do
      other_user = Fabricate(:user)
      target =
        Fabricate(
          :discourse_size_character,
          user: other_user,
          base_size: 100.0,
          character_type: DiscourseSizeCharacter::TYPE_GAME,
        )
      character.update!(
        character_type: DiscourseSizeCharacter::TYPE_GAME,
        base_size: 200.0,
        is_main: true,
      )
      growth = create_item("paired_prefix_growth")
      double = create_item("paired_target_prefix", amount: 100.0)
      shrink = create_item("paired_target_suffix", effect: "shrink", amount: 20.0)
      paired = create_item("paired_growth", self_effect: "grow", self_amount: 25.0)
      own_prefix = use_item(growth)
      target_prefix = use_item(double, target: target)
      parent = use_item(paired, target: target)
      child = parent.child_actions.sole
      own_suffix = use_item(growth)
      target_suffix = use_item(shrink, target: target)

      expect(parent.reload).to have_attributes(effect_type: "grow", effect_amount: 50.0)
      expect(child.reload).to have_attributes(effect_type: "grow", effect_amount: 25.0)
      paired.update!(amount: 90.0, self_amount: 80.0)
      character.reload.rebuild_offset_chain!
      target.reload.rebuild_offset_chain!
      expect(character.reload.current_size).to eq(562.5)
      expect(target.reload.current_size).to eq(240.0)
      original_prefixes = [own_prefix, target_prefix].map { |action| action.reload.attributes }
      freeze_time 1.minute.from_now

      described_class.refund_action(parent)

      expect(DiscourseSizeAction.where(id: [parent.id, child.id])).to be_empty
      expect([own_prefix, target_prefix].map { |action| action.reload.attributes }).to eq(
        original_prefixes,
      )
      expect(own_suffix.reload).to have_attributes(start_offset: 100.0, end_offset: 250.0)
      expect(target_suffix.reload).to have_attributes(start_offset: 100.0, end_offset: 60.0)
      expect(character.reload.current_size).to eq(450.0)
      expect(target.reload.current_size).to eq(160.0)
      expect(
        DiscourseSizeInventory.where(user: user, item_key: paired.key).sum(:uses_remaining),
      ).to eq(1)
      expect(DiscourseSizeInventory.where(user: other_user, item_key: paired.key)).to be_empty
    end

    it "replays snapshotted formulas after the original definitions are physically deleted" do
      double = create_item("deleted_double", amount: 100.0)
      growth = create_item("deleted_growth")
      shrink = create_item("deleted_shrink", effect: "shrink", amount: 20.0)
      static = create_item("deleted_static", effect: "static", amount: 180.0)
      first = use_item(double)
      grown = use_item(growth)
      shrunk = use_item(shrink)
      fixed = use_item(static)
      DiscourseSizeShopItem.where(id: [double.id, growth.id, shrink.id, static.id]).delete_all

      character.reload.rebuild_offset_chain!

      expect(grown.reload).to have_attributes(start_offset: 100.0, end_offset: 200.0)
      expect(shrunk.reload).to have_attributes(start_offset: 200.0, end_offset: 140.0)
      expect(fixed.reload).to have_attributes(start_offset: 140.0, end_offset: 80.0)

      described_class.refund_action(first)

      expect(grown.reload).to have_attributes(
        start_offset: 0.0,
        end_offset: 50.0,
        size_change: 50.0,
      )
      expect(shrunk.reload).to have_attributes(
        start_offset: 50.0,
        end_offset: 20.0,
        size_change: -30.0,
      )
      expect(fixed.reload).to have_attributes(
        start_offset: 20.0,
        end_offset: 80.0,
        size_change: 60.0,
      )
      expect(character.reload.current_size).to eq(180.0)
    end

    it "keeps stored deltas and static endpoints for legacy unsnapshotted actions with missing definitions" do
      double = create_item("legacy_double", amount: 100.0)
      growth = create_item("legacy_growth")
      static = create_item("legacy_static", effect: "static", amount: 180.0)
      shrink = create_item("legacy_shrink", effect: "shrink", amount: 20.0)
      first = use_item(double)
      grown = use_item(growth)
      fixed = use_item(static)
      shrunk = use_item(shrink)
      DiscourseSizeAction.where(id: [grown.id, fixed.id, shrunk.id]).update_all(
        effect_type: nil,
        effect_amount: nil,
      )
      DiscourseSizeShopItem.where(id: [growth.id, static.id, shrink.id]).delete_all

      character.reload.rebuild_offset_chain!
      expect(character.reload.current_size).to eq(144.0)

      described_class.refund_action(first)

      expect(grown.reload).to have_attributes(
        effect_type: nil,
        effect_amount: nil,
        start_offset: 0.0,
        end_offset: 100.0,
        size_change: 100.0,
      )
      expect(fixed.reload).to have_attributes(
        start_offset: 100.0,
        end_offset: 80.0,
        size_change: -20.0,
      )
      expect(shrunk.reload).to have_attributes(
        start_offset: 80.0,
        end_offset: 44.0,
        size_change: -36.0,
      )
      expect(character.reload.current_size).to eq(144.0)
    end

    it "returns a retired item's use and allows that returned inventory to be used again" do
      item = create_item("retired_growth")
      action = use_item(item)
      item.update!(deleted_at: Time.current, enabled: false)

      described_class.refund_action(action)

      inventory = DiscourseSizeInventory.find_by!(user: user, item_key: item.key)
      expect(inventory.uses_remaining).to eq(1)
      expect(character.reload.current_size).to eq(100.0)

      result = described_class.use_item(user, inventory.id, character.id)

      expect(result[:success]).to eq(true), result.inspect
      expect(character.reload.current_size).to eq(150.0)
      expect(DiscourseSizeInventory.exists?(inventory.id)).to eq(false)
      expect(item.reload.deleted_at).to be_present
    end
  end
end

describe DiscourseSizeCharacter do
  fab!(:user)
  fab!(:character) { Fabricate(:discourse_size_character, user: user, base_size: 100.0) }

  describe "#add_queued_action" do
    it "snapshots the item by default and preserves an explicitly supplied effect snapshot" do
      freeze_time
      item =
        DiscourseSizeShopItem.create!(
          key: "queued_snapshot",
          name: "Queued snapshot",
          price: 0,
          effect: "grow",
          amount: 50.0,
          duration_minutes: 0,
          uses: 1,
        )
      first =
        character.add_queued_action(
          action_type: "grow",
          size_change: 50.0,
          duration_minutes: 0,
          user_id: user.id,
          item_key: item.key,
        )[
          :action
        ]
      second =
        character.add_queued_action(
          action_type: "grow",
          size_change: 37.5,
          duration_minutes: 0,
          user_id: user.id,
          item_key: item.key,
          effect_type: "grow",
          effect_amount: 25.0,
        )[
          :action
        ]
      item.update!(amount: 75.0)

      character.rebuild_offset_chain!

      expect(first.reload).to have_attributes(
        effect_type: "grow",
        effect_amount: 50.0,
        end_offset: 50.0,
      )
      expect(second.reload).to have_attributes(
        effect_type: "grow",
        effect_amount: 25.0,
        start_offset: 50.0,
        end_offset: 87.5,
      )
    end
  end
end
