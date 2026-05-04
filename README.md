# Discourse Size

A comprehensive character growth and profile plugin for Discourse. Users can create, customize, and grow characters using a unique exponential growth system or purely for roleplay in freeform mode.

## Features

### 🎭 Character System

- **Multiple Characters**: Users can create and manage multiple character profiles.
- **Dual Modes**:
  - **Game Mode**: Earn and spend "Size Coins" to grow or shrink. Experience real-time compounding exponential growth.
  - **Freeform Mode**: Purely for roleplay—manually set your character's size and metadata without growth restrictions.
- **Main Character**: Select a primary character to be featured on your Discourse user card and profile.

### 📈 Growth Mechanics

- **Exponential Growth**: A sophisticated compounding growth model where size increases (or decreases) dynamically over time.
- **Speed Boosts**: Spend coins to permanently increase your character's growth rate.
- **Real-time Synchronization**: Frontend animations and backend calculations stay perfectly in sync.

### 🖼️ Rich UI & Visualization

- **Custom Character Cards**: Beautifully styled cards featuring:
  - Character avatars and metadata (Gender, Pronouns, Age).
  - Dynamic size comparisons (e.g., "Tall as a mountain", "Small as a mouse").
  - Interactive growth progress bars and time-remaining estimates.
- **Recent Activity Log**: Track every growth event, shrink, or speed boost for each character.
- **Leaderboards**: Competitive rankings for the Biggest and Tiniest characters in Game Mode.

### 🛠️ Administrative Tools

- **Points Management**: Admins can directly adjust user "Size Coin" balances.
- **Character Overrides**: Admins can override character sizes and growth rates for moderation or special events.
- **Global Settings**: Configure minimum/maximum base sizes, growth rate defaults, and measurement systems.

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
- `discourse_size_default_max_growth_rate`: The base percentage growth per day.

## Usage

### Creating a Character

Navigate to your user profile page and look for the **Characters** tab. From there, you can create a new character, upload a picture, and choose between Game or Freeform mode.

### Growing Your Character

In Game Mode, users can earn coins (via site activity or admin grants) and use them on their own characters—or characters of others who allow it—to trigger growth or shrinkage.

## License

MIT
