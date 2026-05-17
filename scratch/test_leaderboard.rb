# frozen_string_literal: true

# Test script for character time remaining calculation
character = DiscourseSizeCharacter.where(character_type: "game").first
if character
  puts "Testing character ID: #{character.id}"
  puts "Current size: #{character.current_size}"
  puts "Target size: #{character.base_size + character.target_offset}"
  puts "Time remaining hours: #{character.time_remaining_hours}"
else
  puts "No game characters found to test."
end
