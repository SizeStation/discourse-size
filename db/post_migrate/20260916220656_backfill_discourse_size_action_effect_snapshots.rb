# frozen_string_literal: true

class BackfillDiscourseSizeActionEffectSnapshots < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  BATCH_SIZE = 30_000

  def up
    last_id = 0

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

      DB.exec(<<~SQL, last_id: last_id, batch_end_id: batch_end_id)
        UPDATE discourse_size_actions AS actions
        SET effect_type = CASE
              WHEN actions.parent_action_id IS NOT NULL AND items.self_effect ~ '\\S'
                THEN items.self_effect
              ELSE items.effect
            END,
            effect_amount = CASE
              WHEN actions.parent_action_id IS NOT NULL AND items.self_effect ~ '\\S'
                THEN items.self_amount
              ELSE items.amount
            END
        FROM discourse_size_shop_items AS items
        WHERE actions.id > :last_id
          AND actions.id <= :batch_end_id
          AND actions.item_key = items.key
          AND actions.action_type IN ('grow', 'shrink', 'set_size')
          AND actions.effect_type IS NULL
          AND actions.effect_amount IS NULL
      SQL

      last_id = batch_end_id
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
