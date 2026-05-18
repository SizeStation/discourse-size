# discourse-size — Agent Guide

## Project

Discourse plugin for character profiles, size growth/roleplay, shop, inventory, leaderboards, triggers, and roleplays.

## Quick start

```bash
pnpm install
bundle install
```

## Key commands

| What | How |
|------|-----|
| Lint JS/CSS/HBS/TS | `pnpm lint` |
| Lint Ruby | `bin/lint <path>` or `bin/lint --fix <path>` |
| Ruby formatter | `bundle exec stree format <file>` |
| Ruby tests | `bin/rspec spec/path/file_spec.rb[:line]` |
| JS tests | `bin/qunit path/to/test.js` |
| Format Ruby files | `ruby format.rb` (uses syntax_tree with trailing_comma + no_auto_ternary) |

## Architecture

- **Two character types**: `game` (exponential growth/shop) and `normal` (static roleplay only). Constants in `DiscourseSizeCharacter::TYPE_GAME` / `TYPE_NORMAL`. Check with `.game?` / `.normal?`.
- **Roleplay member overrides**: `DiscourseSizeRoleplayMember#override_data` (JSONB) stores per-roleplay field deviations. `OVERRIDABLE_FIELDS = %w[name base_size gender pronouns age species description picture]`. Properties, triggers, infoPost, showComparison, isMain, blockedItemKeys are saved directly to the character, not in override_data.
- **Frontend**: Ember/Glimmer components in `assets/javascripts/discourse/components/`. Modal components under `modal/`. Routes use Discourse conventions (`routes/`, `controllers/`, `templates/`).
- **No FormKit usage** — this plugin predates Discourse FormKit adoption; forms use manual `<Input>` / `<Textarea>` / `<DButton>`.
- **No BEM** — CSS is flat with generic class names.
- **Helpers**: `format-size`, `abs`, `add` in `assets/javascripts/discourse/helpers/`.
- **Engine routes**: `config/routes.rb` — all under `DiscourseSize::Engine`.
- **Settings**: `config/settings.yml` — `discourse_size_*` keys. Access: `SiteSetting.discourse_size_*` (Ruby), `siteSettings.discourse_size_*` (JS).
- **Locales**: `config/locales/client.en.yml` (JS strings), `config/locales/server.en.yml` (server strings), `config/locales/en.yml` (fallback).
- **SVG icons** registered in `plugin.rb`: `paw`, `angle-double-up`, `angle-double-down`, `sync`, `wrench`.

## Migration status

The last migration `20260514160000_add_override_data_to_roleplay_members.rb` adds the `override_data` JSONB column and migrates `freeform`/`roleplay` → `normal`. This migration **cannot run from dev** (Ruby 3.3 vs ~> 3.4 required in this env). The fabricator at `spec/fabricators/discourse_size_character_fabricator.rb` still references `TYPE_FREEFORM` — update to `TYPE_NORMAL` when running tests.

## Key gotchas

- Roles and members endpoints use `put "update_member_overrides"` and `post "reset_member_overrides"` as member routes on roleplays.
- `deviates`, `resetField`, and any method called from HBS templates must be decorated with `@action` for proper `this` binding in Glimmer components.
- Field name mapping in JS: `_originalValue(field)` maps camelCase → snake_case (`infoPost` → `info_post`, `showComparison` → `show_comparison`, `isMain` → `is_main`).
- `base_size` deviation uses epsilon comparison (`Math.abs(...) > 0.0001`) to avoid unit-conversion false positives.
- Properties/triggers deviation uses `JSON.stringify` comparison.
- `discourse_size_trigger_category_slug` setting (client: true) drives the "Discover Triggers" button link.
- The character model ignores legacy columns: `allow_growth`, `allow_shrink`, `growth_speed_multiplier`, `measurement_system`, `site_sink`.
- `before_save :ensure_single_main` — only one character can have `is_main = true` per user.
- `before_save :set_folder_position` — setting `folder_id` auto-assigns a position.
- Size is stored in cm (`base_size`), displayed in user's preferred unit via `format-size` helper.
