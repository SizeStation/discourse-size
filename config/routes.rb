# frozen_string_literal: true

MyPluginModule::Engine.routes.draw do
  post "/points/give" => "size#give_points"
  post "/points/change" => "size#change_size"
  post "/admin/points" => "size#admin_set_points"
  post "/admin/size" => "size#admin_set_size"
end

Discourse::Application.routes.draw { mount ::MyPluginModule::Engine, at: "discourse-size" }
