# frozen_string_literal: true

# name: discourse-size
# about: A profile play plugin for the macro/micro and size community
# version: 0.0.1
# authors: Discourse Size Team
# url: https://github.com/discourse/discourse-size
# required_version: 2.7.0

enabled_site_setting :discourse_size_enabled

module ::DiscourseSize
  PLUGIN_NAME = "discourse-size"
end

require_relative "lib/discourse_size/engine"
require_relative "lib/discourse_size/points_manager"
require_relative "lib/discourse_size/inventory_manager"
require_relative "lib/discourse_size/notification_manager"
require_relative "lib/discourse_size/size_calculator"
require_relative "lib/discourse_size/trigger_executor"

register_svg_icon "paw"
register_svg_icon "angle-double-up"
register_svg_icon "angle-double-down"
register_svg_icon "sync"
register_svg_icon "wrench"
register_asset "stylesheets/discourse-size.scss"

after_initialize do
  if respond_to?(:register_notification_type)
    register_notification_type(:discourse_size_notification, 2600)
  else
    Notification.types[:discourse_size_notification] = 2600
  end
  require_relative "app/models/discourse_size_character"
  require_relative "app/models/discourse_size_action"
  require_relative "app/models/discourse_size_folder"
  require_relative "app/models/discourse_size_user_quest"
  require_relative "lib/discourse_size/quest_manager"

  # Settings serialization
  add_to_serializer(:user, :discourse_size_settings) do
    settings = DiscourseSizeUserSetting.for_user(object)
    {
      measurement_system: settings.measurement_system
    }
  end

  add_to_serializer(:current_user, :discourse_size_settings) do
    settings = DiscourseSizeUserSetting.for_user(object)
    {
      measurement_system: settings.measurement_system
    }
  end

  # Daily Reward Status
  add_to_serializer(:current_user, :discourse_size_daily_reward_status) do
    return "collected" if object.custom_fields["discourse_size_last_daily_reward_date"] == Date.today.to_s
    "available"
  end


  # Quest Tracking Hooks
  on(:post_created) do |post, opts, user|
    user ||= post.user
    if SiteSetting.discourse_size_enabled && user
      type = post.is_first_post? ? :topic_created : :post_created
      DiscourseSize::QuestManager.track_activity(user, type, category_id: post.topic&.category_id)
    end
  end



  on(:chat_message_created) do |message, _channel, user|
    if SiteSetting.discourse_size_enabled
      user ||= message.user
      DiscourseSize::QuestManager.track_activity(user, :chat_message_created) if user
    end
  end




  add_to_serializer(:user_card, :discourse_size_main_character) do
    return nil if !object&.id
    character = DiscourseSizeCharacter.find_by(user_id: object.id, is_main: true)
    if character
      character.sync_offset!
      {
        id: character.id,
        name: character.name,
        picture: character.picture,
        info_post: character.info_post,
        current_size: character.current_size,
        target_size: character.base_size + character.target_offset,
        base_size: character.base_size,
        is_growing: character.target_offset > character.current_offset,
        is_shrinking: character.target_offset < character.current_offset,
        gender: character.gender,
        pronouns: character.pronouns,
        age: character.age,
        description: character.description,
        show_comparison: character.show_comparison,
      }
    end
  end

  add_to_serializer(:user, :discourse_size_points) do
    DiscourseSize::PointsManager.get_points(object)
  end

  add_to_serializer(:user, :discourse_size_main_character) do
    return nil if !object&.id
    character = DiscourseSizeCharacter.find_by(user_id: object.id, is_main: true)
    if character
      character.sync_offset!
      {
        id: character.id,
        name: character.name,
        picture: character.picture,
        current_size: character.current_size,
        target_size: character.base_size + character.target_offset,
        is_growing: character.target_offset > character.current_offset,
        is_shrinking: character.target_offset < character.current_offset,
      }
    end
  end

  add_to_serializer(:current_user, :discourse_size_points) do
    DiscourseSize::PointsManager.get_points(object)
  end

  add_to_serializer(:current_user, :pending_roleplay_invites_count) do
    DiscourseSizeRoleplayMember.joins(:character)
      .where(discourse_size_characters: { user_id: object.id }, status: 'pending')
      .count
  end

  Discourse::Application.routes.append do
    mount ::DiscourseSize::Engine, at: "/size"
    get "u/:username/characters" => "users#show", :constraints => { username: RouteFormat.username }
    get "size/shop" => "discourse_size/shop#index"
    get "size/leaderboard" => "discourse_size/leaderboard#index"
    post "size/shop/claim_reward" => "discourse_size/shop#claim_reward"
    get "size/quests" => "discourse_size/quests#index"
    post "size/quests/collect" => "discourse_size/quests#collect"
    post "size/quests/collect_bonus" => "discourse_size/quests#collect_bonus"
    post "size/quests/reroll" => "discourse_size/quests#reroll"
    post "size/quests/get_new" => "discourse_size/quests#get_new_quests"
    post "size/admin/reset_quests" => "discourse_size/admin#reset_quests"
    get "size/roleplays" => "discourse_size/roleplays#index"
    get "size/roleplays/:id" => "discourse_size/roleplays#show"
  end

  if Rails.env.test?
    begin
      FileUtils.mkdir_p(Rails.root.join("public/uploads"))
    rescue
      # Ignore errors if we can't create the directory
    end
  end
end
