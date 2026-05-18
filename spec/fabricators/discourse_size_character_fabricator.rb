# frozen_string_literal: true

Fabricator(:discourse_size_character) do
  user
  name { sequence(:name) { |i| "Character #{i}" } }
  base_size 170.0
  character_type DiscourseSizeCharacter::TYPE_NORMAL
  current_offset 0.0
  start_offset 0.0
  target_offset 0.0
  offset_updated_at Time.now
  blocked_item_keys []
  blocked_user_ids []
end
