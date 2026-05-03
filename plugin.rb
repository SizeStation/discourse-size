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

register_svg_icon "paw"
register_asset "stylesheets/discourse-size.scss"

after_initialize do
  require_relative "app/models/discourse_size_character"
  require_relative "app/models/discourse_size_action"

  # Points for inviting
  on(:user_invited) do |invitee|
    if SiteSetting.discourse_size_enabled && invitee.invited_by
      DiscourseSize::PointsManager.add_points(
        invitee.invited_by,
        SiteSetting.discourse_size_points_per_invite,
      )
    end
  end

  # Points for being invited (redeemed invite)
  on(:user_created) do |user|
    # wait, this doesn't know if they were invited easily without checking invite.
  end

  on(:user_promoted) do |args|
    # When user reaches TL1, we could say they are verified as an invitee.
    # But a better way is to hook into `invite_redeemed`.
  end

  on(:invite_redeemed) do |invite|
    if SiteSetting.discourse_size_enabled
      if invite.user
        DiscourseSize::PointsManager.add_points(
          invite.user,
          SiteSetting.discourse_size_points_per_invited,
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
      DiscourseSize::PointsManager.add_points(user, points)
    end
  end

  # Points for daily login
  on(:user_logged_in) do |user|
    if SiteSetting.discourse_size_enabled
      last_login_date = user.custom_fields["discourse_size_last_daily_login_date"]
      today = Date.today.to_s
      if last_login_date != today
        user.custom_fields["discourse_size_last_daily_login_date"] = today
        user.save_custom_fields(true)
        DiscourseSize::PointsManager.add_points(
          user,
          SiteSetting.discourse_size_points_per_daily_login,
        )
      end
    end
  end

  # Points for reading posts
  on(:post_read) do |post, user|
    # This might be fired frequently, so rate limit or just give small amount
    if SiteSetting.discourse_size_enabled && user
      # Maybe just add 1 point per post, but limit it? "amounts should be configurable"
      # Adding 1 point every single read could hit the DB hard.
      # But we'll do it as requested.
      if rand < 0.1 # 10% chance to give 10x points to reduce DB writes
        DiscourseSize::PointsManager.add_points(
          user,
          SiteSetting.discourse_size_points_per_read,
        )
      end
    end
  end

  add_to_serializer(:user_card, :discourse_size_main_character) do
    character = DiscourseSizeCharacter.find_by(user_id: object.id, is_main: true)
    if character
      character.sync_offset!
      rate =
        character.growth_rate_override ||
          SiteSetting.discourse_size_default_max_growth_rate
      {
        id: character.id,
        name: character.name,
        picture: character.picture,
        info_post: character.info_post,
        current_size: character.current_size,
        target_size: character.base_size + character.target_offset,
        base_size: character.base_size,
        measurement_system: character.measurement_system,
        is_growing:
          character.target_offset > character.current_offset,
        is_shrinking:
          character.target_offset < character.current_offset,
        growth_rate_cm_per_day: rate,
      }
    end
  end

  add_to_serializer(:user, :discourse_size_points) do
    DiscourseSize::PointsManager.get_points(object)
  end

  add_to_serializer(:user, :discourse_size_main_character) do
    character = DiscourseSizeCharacter.find_by(user_id: object.id, is_main: true)
    if character
      character.sync_offset!
      rate =
        character.growth_rate_override ||
          SiteSetting.discourse_size_default_max_growth_rate
      {
        id: character.id,
        name: character.name,
        picture: character.picture,
        current_size: character.current_size,
        target_size: character.base_size + character.target_offset,
        measurement_system: character.measurement_system,
        is_growing: character.target_offset > character.current_offset,
        is_shrinking: character.target_offset < character.current_offset,
        growth_rate_cm_per_day: rate,
      }
    end
  end

  add_to_serializer(:current_user, :discourse_size_points) do
    DiscourseSize::PointsManager.get_points(object)
  end

  Discourse::Application.routes.append do
    mount ::DiscourseSize::Engine, at: "/size"
    get "u/:username/characters" => "users#show",
        constraints: {
          username: RouteFormat.username,
        }
  end
end
