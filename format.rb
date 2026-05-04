# frozen_string_literal: true
require 'syntax_tree'
require 'syntax_tree/plugin/trailing_comma'
require 'syntax_tree/plugin/disable_auto_ternary'

files = [
  'app/controllers/discourse_size/characters_controller.rb',
  'app/controllers/discourse_size/leaderboard_controller.rb',
  'app/models/discourse_size_character.rb',
  'db/migrate/20260503180100_create_discourse_size_tables.rb',
  'db/migrate/20260504015000_add_character_type_to_characters.rb',
  'lib/discourse_size/points_manager.rb',
  'plugin.rb'
]

files.each do |file|
  next unless File.exist?(file)
  source = File.read(file)
  formatted = SyntaxTree.format(source, 100)
  File.write(file, formatted)
  puts "Formatted #{file}"
end
