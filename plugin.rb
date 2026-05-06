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

register_svg_icon "paw"
register_svg_icon "angle-double-up"
register_svg_icon "angle-double-down"
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

  # Settings serialization
  add_to_serializer(:user, :discourse_size_settings) do
    settings = DiscourseSizeUserSetting.for_user(object)
    {
      measurement_system: settings.measurement_system,
      hide_reward_notice: settings.hide_reward_notice
    }
  end

  add_to_serializer(:current_user, :discourse_size_settings) do
    settings = DiscourseSizeUserSetting.for_user(object)
    {
      measurement_system: settings.measurement_system,
      hide_reward_notice: settings.hide_reward_notice
    }
  end

  # Check if daily reward is claimable
  add_to_serializer(:current_user, :discourse_size_can_claim_daily_reward) do
    return false unless SiteSetting.discourse_size_enabled
    settings = DiscourseSizeUserSetting.for_user(object)
    return false if settings.hide_reward_notice

    last_reward_date = object.custom_fields["discourse_size_last_daily_reward_date"]
    dismissed_date = object.custom_fields["discourse_size_dismissed_reward_notice_date"]
    today = Date.today.to_s

    last_reward_date != today && dismissed_date != today
  end

  # Points for inviting / being invited
  on(:invite_redeemed) do |invite|
    if SiteSetting.discourse_size_enabled
      # Points for the person who joined
      if invite.user
        DiscourseSize::PointsManager.add_points(
          invite.user,
          SiteSetting.discourse_size_points_per_invited,
          source_type: "invite_reward",
          description: "Joined via invite from #{invite.invited_by&.username}"
        )
      end
      # Points for the person who sent the invite
      if invite.invited_by
        DiscourseSize::PointsManager.add_points(
          invite.invited_by,
          SiteSetting.discourse_size_points_per_invite,
          source_type: "invite_reward",
          description: "Invited #{invite.user&.username}"
        )
      end
    end
  end

  # Points for when a user is created via an invite link (fallback)
  on(:user_created) do |user|
    if SiteSetting.discourse_size_enabled && user.invited_by_id
      inviter = User.find_by(id: user.invited_by_id)
      if inviter
        DiscourseSize::PointsManager.add_points(
          user,
          SiteSetting.discourse_size_points_per_invited,
          source_type: "invite_reward",
          description: "Joined via invite from #{inviter.username}"
        )
        DiscourseSize::PointsManager.add_points(
          inviter,
          SiteSetting.discourse_size_points_per_invite,
          source_type: "invite_reward",
          description: "Invited #{user.username}"
        )
      end
    end
  end

  # Points for posting a reply / new thread
  on(:post_created) do |post, opts, user|
    if SiteSetting.discourse_size_enabled && user
      points =
        (
          if post.is_first_post?
            SiteSetting.discourse_size_points_per_topic
          else
            SiteSetting.discourse_size_points_per_reply
          end
        )
      DiscourseSize::PointsManager.add_points(
        user,
        points,
        source_type: "post_reward",
        description: post.is_first_post? ? "Created topic" : "Replied to post"
      )
    end
  end

  # Points for reading posts
  on(:post_read) do |post, user|
    if SiteSetting.discourse_size_enabled && user
      DiscourseSize::PointsManager.add_points(
        user,
        SiteSetting.discourse_size_points_per_read,
        source_type: "read_reward"
      )
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

  Discourse::Application.routes.append do
    mount ::DiscourseSize::Engine, at: "/size"
    get "u/:username/characters" => "users#show", :constraints => { username: RouteFormat.username }
    get "size/shop" => "discourse_size/shop#index"
    get "size/leaderboard" => "discourse_size/leaderboard#index"
    post "size/shop/claim_reward" => "discourse_size/shop#claim_reward"
    post "size/shop/dismiss_reward_notice" => "discourse_size/shop#dismiss_reward_notice"
  end
end
