# frozen_string_literal: true

require './config/environment'

puts "Testing PointsManager.get_points(nil)..."
points = DiscourseSize::PointsManager.get_points(nil)
puts "Result: #{points.inspect}"
if points == 0
  puts "SUCCESS: Returns 0 for nil user"
else
  puts "FAILURE: Returns #{points.inspect} for nil user"
end

puts "\nTesting PointsManager.add_points(nil, 10)..."
begin
  DiscourseSize::PointsManager.add_points(nil, 10)
  puts "SUCCESS: Did not crash for nil user"
rescue => e
  puts "FAILURE: Crashed with #{e.message}"
end

puts "\nTesting PointsManager.remove_points(nil, 10)..."
begin
  DiscourseSize::PointsManager.remove_points(nil, 10)
  puts "SUCCESS: Did not crash for nil user"
rescue => e
  puts "FAILURE: Crashed with #{e.message}"
end

puts "\nTesting PointsManager.set_points(nil, 10)..."
begin
  DiscourseSize::PointsManager.set_points(nil, 10)
  puts "SUCCESS: Did not crash for nil user"
rescue => e
  puts "FAILURE: Crashed with #{e.message}"
end
