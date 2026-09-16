# frozen_string_literal: true

require "rails_helper"
require_relative "../../db/post_migrate/20260916220656_backfill_discourse_size_action_effect_snapshots"

RSpec.describe BackfillDiscourseSizeActionEffectSnapshots do
  fab!(:character, :discourse_size_character)
  fab!(:item) do
    DiscourseSizeShopItem.create!(
      key: "snapshot_potion",
      name: "Snapshot potion",
      price: 10,
      effect: "shrink",
      amount: 25.0,
      self_effect: "grow",
      self_amount: 50.0,
      uses: 1,
    )
  end

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  def create_action(**attributes)
    attributes = {
      character_id: character.id,
      user_id: character.user_id,
      action_type: "shrink",
      item_key: item.key,
      parent_action_id: nil,
      effect_type: nil,
      effect_amount: nil,
    }.merge(attributes)

    DB.query_single(<<~SQL, attributes).first
      INSERT INTO discourse_size_actions (
        character_id, user_id, action_type, item_key, parent_action_id,
        effect_type, effect_amount, size_change, start_offset, end_offset,
        duration_minutes, speed, start_time, end_time, created_at, updated_at
      ) VALUES (
        :character_id, :user_id, :action_type, :item_key, :parent_action_id,
        :effect_type, :effect_amount, -40, 10, -30,
        30, 2, NOW() - INTERVAL '10 minutes', NOW() + INTERVAL '20 minutes', NOW(), NOW()
      ) RETURNING id
    SQL
  end

  def action_attributes(id)
    DB.query("SELECT * FROM discourse_size_actions WHERE id = :id", id: id).first.to_h
  end

  describe "#up" do
    it "uses the target formula for parents and the self formula for linked children without changing other action data" do
      parent_id = create_action
      child_id = create_action(action_type: "grow", parent_action_id: parent_id)
      original_attributes = [parent_id, child_id].map { |id| action_attributes(id) }

      described_class.new.up

      expect(action_attributes(parent_id)).to include(effect_type: "shrink", effect_amount: 25.0)
      expect(action_attributes(child_id)).to include(effect_type: "grow", effect_amount: 50.0)
      [parent_id, child_id].each_with_index do |id, index|
        expect(action_attributes(id).except(:effect_type, :effect_amount)).to eq(
          original_attributes[index].except(:effect_type, :effect_amount),
        )
      end
    end

    it "backfills static formulas for set-size actions even when the definition is retired" do
      item.update!(
        effect: "static",
        amount: 200,
        self_effect: "static",
        self_amount: 100,
        deleted_at: Time.current,
        enabled: false,
      )
      parent_id = create_action(action_type: "set_size")
      child_id = create_action(action_type: "set_size", parent_action_id: parent_id)

      described_class.new.up

      expect(action_attributes(parent_id)).to include(effect_type: "static", effect_amount: 200.0)
      expect(action_attributes(child_id)).to include(effect_type: "static", effect_amount: 100.0)
    end

    it "uses the target formula for linked children when the self effect is blank" do
      parent_id = create_action

      [nil, "", " \t\n"].each do |self_effect|
        item.update!(self_effect: self_effect)
        child_id = create_action(parent_action_id: parent_id)

        described_class.new.up

        expect(action_attributes(child_id)).to include(effect_type: "shrink", effect_amount: 25.0)
      end
    end

    it "leaves missing definitions, non-item actions, and non-size actions without snapshots" do
      action_ids = [create_action(item_key: "missing_definition"), create_action(item_key: nil)]
      %w[reset boost_speed set_main unset_main trigger property_change].each do |action_type|
        action_ids << create_action(action_type: action_type)
      end
      original_attributes = action_ids.map { |id| action_attributes(id) }

      described_class.new.up

      expect(action_ids.map { |id| action_attributes(id) }).to eq(original_attributes)
    end

    it "preserves existing snapshots across batches and reruns while filling newly written legacy actions" do
      recorded_id = create_action(effect_type: "grow", effect_amount: 75.0)
      partial_type_id = create_action(effect_type: "static")
      partial_amount_id = create_action(effect_amount: 123.0)
      missing_id = create_action(item_key: "missing_definition")
      legacy_id = create_action
      preserved_ids = [recorded_id, partial_type_id, partial_amount_id, missing_id]
      original_attributes = preserved_ids.map { |id| action_attributes(id) }
      migration = described_class.new

      stub_const(described_class, :BATCH_SIZE, 2) do
        migration.up
        item.update!(amount: 40)
        late_legacy_id = create_action
        migration.up

        expect(preserved_ids.map { |id| action_attributes(id) }).to eq(original_attributes)
        expect(action_attributes(legacy_id)).to include(effect_type: "shrink", effect_amount: 25.0)
        expect(action_attributes(late_legacy_id)).to include(
          effect_type: "shrink",
          effect_amount: 40.0,
        )
      end
    end
  end
end
