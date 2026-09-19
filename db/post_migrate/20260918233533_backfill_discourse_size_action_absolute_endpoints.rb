# frozen_string_literal: true

class BackfillDiscourseSizeActionAbsoluteEndpoints < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  BATCH_SIZE = 1_000

  def up
    last_id = 0

    # Run only after offset-only writers have stopped. Readers must support nil endpoints
    # until every batch completes. Lock characters before actions, as live writers do.
    loop do
      batch_end_id = DB.query_single(<<~SQL, last_id: last_id, batch_size: BATCH_SIZE).first
        SELECT MAX(id)
        FROM (
          SELECT id
          FROM discourse_size_actions
          WHERE id > :last_id
          ORDER BY id
          LIMIT :batch_size
        ) AS batch
      SQL
      break unless batch_end_id

      # PostgreSQL raises on finite float overflow instead of returning Infinity.
      # Halving very large positive operands detects that case without overflowing;
      # two negative operands always reconstruct a size below the minimum.
      DB.exec(<<~SQL, last_id: last_id, batch_end_id: batch_end_id)
        WITH locked_characters AS MATERIALIZED (
          SELECT characters.id, characters.base_size
          FROM discourse_size_characters AS characters
          WHERE EXISTS (
            SELECT 1
            FROM discourse_size_actions AS actions
            WHERE actions.character_id = characters.id
              AND actions.id > :last_id
              AND actions.id <= :batch_end_id
              AND actions.action_type IN ('grow', 'shrink', 'set_size')
              AND (actions.start_size IS NULL OR actions.end_size IS NULL)
          )
          ORDER BY characters.id
          FOR UPDATE OF characters
        )
        UPDATE discourse_size_actions AS actions
        SET start_size = COALESCE(actions.start_size,
              CASE
                WHEN characters.base_size IN ('NaN'::float8, 'Infinity'::float8, '-Infinity'::float8)
                  OR actions.start_offset IN ('NaN'::float8, 'Infinity'::float8, '-Infinity'::float8)
                  THEN 1e-35::float8
                WHEN characters.base_size < 0 AND actions.start_offset < 0
                  THEN 1e-35::float8
                WHEN characters.base_size > 1e120 AND actions.start_offset > 1e120 THEN
                  CASE
                    WHEN characters.base_size / 2 + actions.start_offset / 2 > '1.7976931348623157e308'::float8 / 2
                      THEN 1e-35::float8
                    ELSE 1e120::float8
                  END
                ELSE LEAST(1e120::float8, GREATEST(1e-35::float8,
                  characters.base_size + COALESCE(actions.start_offset, 0)))
              END),
            end_size = COALESCE(actions.end_size,
              CASE
                WHEN characters.base_size IN ('NaN'::float8, 'Infinity'::float8, '-Infinity'::float8)
                  OR actions.end_offset IN ('NaN'::float8, 'Infinity'::float8, '-Infinity'::float8)
                  THEN 1e-35::float8
                WHEN characters.base_size < 0 AND actions.end_offset < 0
                  THEN 1e-35::float8
                WHEN characters.base_size > 1e120 AND actions.end_offset > 1e120 THEN
                  CASE
                    WHEN characters.base_size / 2 + actions.end_offset / 2 > '1.7976931348623157e308'::float8 / 2
                      THEN 1e-35::float8
                    ELSE 1e120::float8
                  END
                ELSE LEAST(1e120::float8, GREATEST(1e-35::float8,
                  characters.base_size + COALESCE(actions.end_offset, 0)))
              END)
        FROM locked_characters AS characters
        WHERE actions.character_id = characters.id
          AND actions.id > :last_id
          AND actions.id <= :batch_end_id
          AND actions.action_type IN ('grow', 'shrink', 'set_size')
          AND (actions.start_size IS NULL OR actions.end_size IS NULL)
      SQL

      last_id = batch_end_id
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
