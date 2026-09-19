# Discourse Size

A character plugin where characters can grow and shrink based on items from a shop. Intended for use by macro/micro size difference communities.

Features:

- Configurable shop with static and percentage based growth/shrinking, as well as self effects for things like size theft.
- Animated character profiles with their own item queues and history graphs.
- Blocking items or people, refunding given items
- Daily random quests to earn coins for items

## Retired shop items

Deleting an item retires it instead of removing it. Retired items are hidden and cannot be purchased, edited, or reordered, but existing inventory items remain usable and can be refunded. Their keys stay reserved.

## Max and Min Heights

Height actions (`grow`, `shrink`, `set_size`) store `start_size` and `end_size` in centimeters. The sizes can vary between `1e-35..1e120 cm`.

Created by @midblep using the skeleton template.
