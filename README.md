# Discourse Size

A comprehensive character growth and profile plugin for Discourse. Users can create, customize, and grow characters using a unique exponential growth system or purely for roleplay in static mode.

## Features

### 🎭 Character System

- **Multiple Characters**: Users can create and manage multiple character profiles.
- **Dual Modes**:
  - **Game Mode**: Earn and spend "Size Coins" to grow or shrink. Experience real-time compounding exponential growth.
  - **Static Mode**: Purely for roleplay—manually set your character's size and metadata without growth restrictions.
- **Main Character**: Select a primary character to be featured on your Discourse user card and profile.
- **Blocking System**: Control who can interact with your character. Block specific users or types of items (e.g., block all shrinking items).
- **Folders**: Organize your characters into custom folders for better management.

### 🛍️ Economy & Shop

- **Size Coins**: Earn coins through forum activity (posting topics, replying, reading) or daily rewards.
- **Dynamic Shop**:
  - Purchase items with various effects (Grow, Shrink, Speed Boost).
  - **Section Headers**: Admins can organize the shop with full-width visual separators.
  - **Reordering**: Drag-and-drop reordering for admins to highlight featured items.
  - **Popularity Tracking**: Every item shows how many times it has been purchased.
- **Inventory & Gifting**: Keep purchased items in your inventory or gift them to friends.
- **Mutual Effects**: Some advanced items have "Size Stealing" effects, impacting both the target and the user who applied the item.

### 📈 Growth Mechanics

- **Exponential Growth**: A sophisticated compounding growth model where size increases (or decreases) dynamically over time.
- **Speed Boosts**: Spend coins to permanently increase your character's growth rate.
- **Real-time Synchronization**: Frontend animations and backend calculations stay perfectly in sync.

### 🖼️ Rich UI & Visualization

- **Custom Character Cards**: Beautifully styled cards featuring:
  - Character avatars and metadata (Gender, Pronouns, Age).
  - Dynamic size comparisons (e.g., "Tall as a mountain", "Small as a mouse").
  - Interactive growth progress bars and time-remaining estimates.
- **Measurement Systems**: Support for both Imperial (ft/in) and Metric (cm/m) systems, configurable per user.
- **Recent Activity Log**: Track every growth event, shrink, or speed boost for each character.
- **Leaderboards**: Competitive rankings for the Biggest and Tiniest characters in Game Mode, featuring trend indicators (Climbing/Descending).

### 🛠️ Administrative Tools

- **Points Management**: Admins can directly adjust user "Size Coin" balances.
- **Character Overrides**: Admins can override character sizes and growth rates.
- **Inventory Control**: Admins can view, add, or remove items from any user's inventory.
- **Transaction Audit**: Full point history/transaction logs visible to admins for any user.
- **Daily Reward Management**: Reset a user's daily reward status to allow them to collect again.

## Installation

1. Add the plugin repository URL to your `containers/app.yml`:
   ```yaml
   hooks:
     after_code:
       - exec:
           cd: $home/plugins
           cmd:
             - git clone https://github.com/your-repo/discourse-size.git
   ```
2. Rebuild your Discourse instance:
   ```bash
   ./launcher rebuild app
   ```

## Configuration

Settings are available in the Discourse Admin panel under the **Plugins** tab or by searching for "discourse size".

- `discourse_size_enabled`: Enable or disable the plugin.
- `discourse_size_min_base_size`: Minimum starting size for characters (cm).
- `discourse_size_max_base_size`: Maximum starting size for characters (cm).
- `discourse_size_daily_reward_amount`: Number of coins granted daily.
- `discourse_size_points_per_topic/reply/read`: Configure activity-based earnings.

## License

MIT
