# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-size/db/post_migrate/20260918233533_backfill_discourse_size_action_absolute_endpoints.rb",
        )

RSpec.describe BackfillDiscourseSizeActionAbsoluteEndpoints do
  fab!(:user)

  def insert_character(base_size: 170, character_type: "normal")
    DB.query_single(
      <<~SQL,
      INSERT INTO discourse_size_characters (
        user_id, name, base_size, character_type, offset_updated_at, created_at, updated_at
      ) VALUES (
        :user_id, 'Legacy character', CAST(:base_size AS float8), :character_type,
        '2026-01-01 12:00:00', '2026-01-01 10:00:00', '2026-01-01 11:00:00'
      ) RETURNING id
    SQL
      user_id: user.id,
      base_size: base_size.to_s,
      character_type: character_type,
    ).first
  end

  def insert_action(
    character_id:,
    action_type: "grow",
    start_offset: nil,
    end_offset: nil,
    start_size: nil,
    end_size: nil,
    parent_action_id: nil
  )
    DB.query_single(
      <<~SQL,
      INSERT INTO discourse_size_actions (
        character_id, user_id, action_type, start_offset, end_offset, start_size, end_size,
        size_change, points_spent, speed, duration_minutes, start_time, end_time,
        item_key, effect_type, effect_amount, parent_action_id, notification_id, created_at, updated_at
      ) VALUES (
        :character_id, :user_id, :action_type, CAST(:start_offset AS float8), CAST(:end_offset AS float8),
        :start_size, :end_size, -37.5, 12.5, 2.5, 60,
        '2026-01-01 12:00:00', '2026-01-01 13:00:00',
        'retired_item', 'static', 999, :parent_action_id, 123,
        '2026-01-01 10:00:00', '2026-01-01 11:00:00'
      ) RETURNING id
    SQL
      character_id: character_id,
      user_id: user.id,
      action_type: action_type,
      start_offset: start_offset&.to_s,
      end_offset: end_offset&.to_s,
      start_size: start_size,
      end_size: end_size,
      parent_action_id: parent_action_id,
    ).first
  end

  def endpoints(action_id)
    DB.query(<<~SQL, id: action_id).first.to_h
      SELECT start_size, end_size FROM discourse_size_actions WHERE id = :id
    SQL
  end

  def action_history
    DB.query_single(<<~SQL)
      SELECT (to_jsonb(actions) - 'start_size' - 'end_size')::text
      FROM discourse_size_actions AS actions
      ORDER BY id
    SQL
  end

  describe "#up" do
    it "adds nullable endpoints without defaults for transitional and non-height rows" do
      columns = ActiveRecord::Base.connection.columns(:discourse_size_actions)

      expect(
        columns
          .select { |column| %w[start_size end_size].include?(column.name) }
          .map { |column| [column.name, column.type, column.null, column.default] },
      ).to contain_exactly(["start_size", :float, true, nil], ["end_size", :float, true, nil])
    end

    it "reconstructs height endpoints without replaying effects or changing history" do
      character_id = insert_character(character_type: "game")
      grow_id = insert_action(character_id: character_id, start_offset: 10, end_offset: 30)
      shrink_id =
        insert_action(
          character_id: character_id,
          action_type: "shrink",
          start_offset: 30,
          end_offset: -50,
          parent_action_id: grow_id,
        )
      set_size_id =
        insert_action(
          character_id: character_id,
          action_type: "set_size",
          start_offset: nil,
          end_offset: 0,
        )
      DB.exec(<<~SQL, id: set_size_id)
        UPDATE discourse_size_actions SET start_time = NULL, end_time = NULL WHERE id = :id
      SQL
      history = action_history

      described_class.new.up

      expect(endpoints(grow_id)).to eq(start_size: 180, end_size: 200)
      expect(endpoints(shrink_id)).to eq(start_size: 200, end_size: 120)
      expect(endpoints(set_size_id)).to eq(start_size: 170, end_size: 170)
      expect(action_history).to eq(history)
    end

    it "preserves non-height actions, properties, and every character field" do
      character_id = insert_character
      action_ids =
        %w[reset boost_speed set_main unset_main trigger property_change].map do |action_type|
          insert_action(
            character_id: character_id,
            action_type: action_type,
            start_offset: 23,
            end_offset: 42,
          )
        end
      property_action_id =
        insert_action(
          character_id: character_id,
          action_type: "property_change",
          start_size: 11,
          end_size: 22,
        )
      insert_action(character_id: character_id, start_offset: 0, end_offset: 10)
      DB.exec(<<~SQL, character_id: character_id)
        INSERT INTO discourse_size_character_properties (
          character_id, name, property_type, value, linked_to_size, link_ratio, created_at, updated_at
        ) VALUES (
          :character_id, 'Wingspan', 'size', '340', true, 2,
          '2026-01-01 10:00:00', '2026-01-01 11:00:00'
        )
      SQL
      characters =
        DB.query_single(
          "SELECT to_jsonb(characters)::text FROM discourse_size_characters AS characters ORDER BY id",
        )
      properties =
        DB.query_single(
          "SELECT to_jsonb(properties)::text FROM discourse_size_character_properties AS properties ORDER BY id",
        )
      history = action_history

      described_class.new.up

      expect(action_ids.map { |action_id| endpoints(action_id) }).to eq(
        Array.new(action_ids.length) { { start_size: nil, end_size: nil } },
      )
      expect(endpoints(property_action_id)).to eq(start_size: 11, end_size: 22)
      expect(action_history).to eq(history)
      expect(
        DB.query_single(
          "SELECT to_jsonb(characters)::text FROM discourse_size_characters AS characters ORDER BY id",
        ),
      ).to eq(characters)
      expect(
        DB.query_single(
          "SELECT to_jsonb(properties)::text FROM discourse_size_character_properties AS properties ORDER BY id",
        ),
      ).to eq(properties)
    end

    it "fills each null endpoint independently and preserves existing absolute values verbatim" do
      character_id = insert_character
      start_only = insert_action(character_id: character_id, start_size: 0, end_offset: 10)
      end_only = insert_action(character_id: character_id, start_offset: -10, end_size: 1e130)
      complete = insert_action(character_id: character_id, start_size: 12, end_size: 34)

      described_class.new.up

      expect(endpoints(start_only)).to eq(start_size: 0, end_size: 180)
      expect(endpoints(end_only)).to eq(start_size: 160, end_size: 1e130)
      expect(endpoints(complete)).to eq(start_size: 12, end_size: 34)
    end

    it "clamps raw zero, negative, tiny, and high finite sizes at both endpoints" do
      cases = [
        [170, -170, -171, 1e-35, 1e-35],
        [1e-40, nil, 1e-36, 1e-35, 1e-35],
        [1e-35, 0, 1e-35, 1e-35, 2e-35],
        [1e120, nil, 1e120, 1e120, 1e120],
        [1e121, 0, 1e121, 1e120, 1e120],
        [0, 1e-20, 1e100, 1e-20, 1e100],
      ]
      expected =
        cases.to_h do |base_size, start_offset, end_offset, start_size, end_size|
          action_id =
            insert_action(
              character_id: insert_character(base_size: base_size),
              start_offset: start_offset,
              end_offset: end_offset,
            )
          [action_id, { start_size: start_size, end_size: end_size }]
        end
      history = action_history

      described_class.new.up

      expect(expected.keys.to_h { |action_id| [action_id, endpoints(action_id)] }).to eq(expected)
      expect(action_history).to eq(history)
    end

    it "maps nonfinite reconstructed sizes, including float overflow, to the minimum" do
      character_id = insert_character
      cases = %w[NaN Infinity -Infinity]
      action_ids =
        cases.flat_map do |value|
          [
            insert_action(character_id: character_id, start_offset: value, end_offset: value),
            insert_action(character_id: insert_character(base_size: value)),
          ]
        end
      [1e308, -1e308].each do |base_size|
        action_ids << insert_action(
          character_id: insert_character(base_size: base_size),
          start_offset: base_size,
          end_offset: base_size,
        )
      end
      large_finite_id =
        insert_action(
          character_id: insert_character(base_size: 1e308),
          start_offset: 1e307,
          end_offset: 0,
        )
      history = action_history

      described_class.new.up

      expect(action_ids.map { |action_id| endpoints(action_id) }).to eq(
        Array.new(action_ids.length) { { start_size: 1e-35, end_size: 1e-35 } },
      )
      expect(endpoints(large_finite_id)).to eq(start_size: 1e120, end_size: 1e120)
      expect(action_history).to eq(history)
    end

    it "backfills across batches and is idempotent even when characters later change" do
      character_id = insert_character
      first_id = insert_action(character_id: character_id, start_offset: 10, end_offset: 20)
      insert_action(character_id: character_id, action_type: "property_change")
      insert_action(character_id: character_id, action_type: "trigger")
      last_id = insert_action(character_id: character_id, start_offset: 20, end_offset: 30)

      stub_const(described_class, "BATCH_SIZE", 1) { described_class.new.up }

      expect(endpoints(first_id)).to eq(start_size: 180, end_size: 190)
      expect(endpoints(last_id)).to eq(start_size: 190, end_size: 200)
      snapshot =
        DB.query_single(
          "SELECT to_jsonb(actions)::text FROM discourse_size_actions AS actions ORDER BY id",
        )
      DB.exec(
        "UPDATE discourse_size_characters SET base_size = 300 WHERE id = :id",
        id: character_id,
      )

      described_class.new.up

      expect(
        DB.query_single(
          "SELECT to_jsonb(actions)::text FROM discourse_size_actions AS actions ORDER BY id",
        ),
      ).to eq(snapshot)
    end
  end
end
