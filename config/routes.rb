# frozen_string_literal: true

DiscourseSize::Engine.routes.draw do
  get "characters" => "characters#index"
  get "characters/:id" => "characters#show"
  post "characters" => "characters#create"
  put "characters/:id" => "characters#update"
  delete "characters/:id" => "characters#destroy"
  post "characters/:id/set_size" => "characters#set_size"
  post "characters/:id/set_main" => "characters#set_main"
  post "characters/:id/unset_main" => "characters#unset_main"
  post "characters/:id/block_user" => "characters#block_user"
  post "characters/:id/unblock_user" => "characters#unblock_user"
  post "characters/:id/update_blocked_items" => "characters#update_blocked_items"
  post "characters/reorder" => "characters#reorder"
  post "characters/reorder_top_level" => "characters#reorder_top_level"
  delete "actions/:id" => "characters#destroy_action"

  resources :folders, only: [:create, :update, :destroy] do
    post "reorder", on: :collection
  end

  get "leaderboard" => "leaderboard#index"
  get "shop" => "shop#index"
  post "shop/purchase" => "shop#purchase"
  post "shop/save_settings" => "shop#save_settings"
  get "inventory" => "inventory#index"
  post "inventory/use" => "inventory#use"
  post "inventory/gift" => "inventory#gift"
  get "point_history" => "point_history#index"
  delete "point_history/:id" => "point_history#destroy"

  # Admin actions
  put "admin/characters/:id" => "admin#update_character"
  post "admin/characters/:id/sync" => "admin#sync_character"
  put "admin/users/:user_id/points" => "admin#update_points"
  get "admin/users/:user_id/inventory" => "admin#user_inventory"
  get "admin/users/:user_id/point_history" => "admin#user_point_history"
  post "admin/users/:user_id/inventory" => "admin#add_inventory_item"
  delete "admin/users/:user_id/inventory/:id" => "admin#remove_inventory_item"
  post "admin/users/:user_id/clear_daily_reward" => "admin#clear_daily_reward"

  post "admin/shop_items" => "shop#create"
  put "admin/shop_items/:id" => "shop#update"
  delete "admin/shop_items/:id" => "shop#destroy"
  post "admin/shop_items/reorder" => "shop#reorder"
end
