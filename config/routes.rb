# frozen_string_literal: true

DiscourseSize::Engine.routes.draw do
  put "/preferences" => "size#update_preferences"
  post "/picture" => "size#upload_picture"
  post "/spend" => "size#spend_points"
  get "/compare" => "size#compare"
  post "/admin/override" => "admin_size#override_user"
end

Discourse::Application.routes.draw { mount ::DiscourseSize::Engine, at: "discourse-size" }
