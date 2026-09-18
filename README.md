# Discourse Size

A character plugin where characters can grow and shrink based on items from a shop. Intended for use by macro/micro size difference communities.

Features:

- Configurable shop with static and percentage based growth/shrinking, as well as self effects for things like size theft.
- Animated character profiles with their own item queues and history graphs.
- Blocking items or people, refunding given items
- Daily random quests to earn coins for items

## Retired shop items

Deleting an item retires it instead of removing it. Retired items are hidden and cannot be purchased, edited, or reordered, but existing inventory items remain usable and can be refunded. Their keys stay reserved.

## Uses that do not change size

Item use checks the last queued size endpoint on the server, including applicable self-effects. If an effect would leave the stored size unchanged, the API returns `confirmation_required` and `no_size_effects` without consuming a use, creating actions, advancing quests, or sending notifications. The UI explains the affected characters and asks whether to proceed. A second request with `confirm_no_size_change: true` applies the item normally, including any useful self-effect. Cancelling leaves the inventory untouched.

This also detects precision-related stalls above the configured minimum. Sizes are still stored as floating-point offsets from the base: for example, at base `100 cm` and offset `-99.99999999999997 cm`, a 25% shrink records an intended change of about `71.1 am`, but rounds back to the same offset. Identical formatted history amounts alone do not prove a stall; compare the raw start and end offsets. The confirmation prevents uninformed consumption, but does not repair historical amounts or the underlying representation. Supporting the full size range requires coordinated changes to endpoint storage, replay/refunds, and server/client interpolation, not just more display decimals.

## Effect snapshot migration

Actions now store the effect and amount used when they were created. The pre-deploy migration adds these fields and `deleted_at`; the post-deploy migration fills snapshots for existing actions in batches. Run post-migrations separately if your deployment skips them.

The backfill only uses definitions that still exist and does not overwrite existing action data. It cannot recover formulas from permanently deleted items or older versions of edited items.

Created by @midblep using the skeleton template.
