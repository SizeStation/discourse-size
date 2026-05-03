# frozen_string_literal: true

module ::DiscourseSize
  class Engine < ::Rails::Engine
    engine_name "discourse_size"
    isolate_namespace DiscourseSize
  end
end
