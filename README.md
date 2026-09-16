# Discourse Size

A character plugin where characters can grow and shrink based on items from a shop. Intended for use by macro/micro size difference communities.

Features:

- Configurable shop with static and percentage based growth/shrinking, as well as self effects for things like size theft.
- Animated character profiles with their own item queues and history graphs.
- Blocking items or people, refunding given items
- Daily random quests to earn coins for items

## Retired shop items

Deleting an item retires it instead of removing it. Retired items are hidden and cannot be purchased, edited, or reordered, but existing inventory items remain usable and can be refunded. Their keys stay reserved.

## Effect snapshot migration

Actions now store the effect and amount used when they were created. The pre-deploy migration adds these fields and `deleted_at`; the post-deploy migration fills snapshots for existing actions in batches. Run post-migrations separately if your deployment skips them.

The backfill only uses definitions that still exist and does not overwrite existing action data. It cannot recover formulas from permanently deleted items or older versions of edited items.

Created by @midblep using the skeleton template.
