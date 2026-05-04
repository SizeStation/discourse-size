require 'syntax_tree'
require 'syntax_tree/plugin/trailing_comma'
require 'syntax_tree/plugin/disable_auto_ternary'

files = [
  'app/controllers/discourse_size/characters_controller.rb',
  'app/controllers/discourse_size/leaderboard_controller.rb',
  'app/models/discourse_size_character.rb',
  'db/migrate/20260503180100_create_discourse_size_tables.rb',
  'plugin.rb'
]

formatter = SyntaxTree::Formatter.new(
  source: "",
  *[],
  options: SyntaxTree::Formatter::Options.new(print_width: 100)
)

files.each do |file|
  source = File.read(file)
  formatted = SyntaxTree.format(source)
  File.write(file, formatted)
  puts "Formatted #{file}"
end
