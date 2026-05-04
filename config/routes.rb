# frozen_string_literal: true

DiscourseSize::Engine.routes.draw do
  get "characters" => "characters#index"
  post "characters" => "characters#create"
  put "characters/:id" => "characters#update"
  delete "characters/:id" => "characters#destroy"
  post "characters/:id/grow" => "characters#grow"
  post "characters/:id/shrink" => "characters#shrink"
  post "characters/:id/reset" => "characters#reset_size"
  post "characters/:id/set_main" => "characters#set_main"
  post "characters/:id/unset_main" => "characters#unset_main"

  get "leaderboard" => "leaderboard#index"

  # Admin actions
  put "admin/characters/:id" => "admin#update_character"
  put "admin/users/:user_id/points" => "admin#update_points"
end
