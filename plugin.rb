# frozen_string_literal: true

# name: discourse-size
# about: A Discourse plugin adding character size stats and point-based growth mechanics.
# meta_topic_id: TODO
# version: 0.0.1
# authors: Discourse & System
# url: TODO
# required_version: 2.7.0

enabled_site_setting :size_plugin_enabled

module ::DiscourseSize
  PLUGIN_NAME = "discourse-size"
end

require_relative "lib/discourse_size/engine"

after_initialize do
  # Require our model
  require_dependency File.expand_path("app/models/user_size_stat.rb", __dir__)

  # Add user_size_stat to User
  add_to_class(:user, :user_size_stat) do
    @user_size_stat ||= UserSizeStat.find_or_create_by(user_id: self.id)
  end

  # Add fields to User Serializer
  add_to_serializer(:user, :size_stat_current_size) do
    object.user_size_stat.current_size
  end
  add_to_serializer(:user, :size_stat_target_size) do
    object.user_size_stat.target_size
  end
  add_to_serializer(:user, :size_stat_is_changing) do
    object.user_size_stat.base_size != object.user_size_stat.target_size
  end
  add_to_serializer(:user, :size_stat_points) do
    object.user_size_stat.points
  end
  add_to_serializer(:user, :size_stat_measurement_system) do
    object.user_size_stat.measurement_system
  end
  add_to_serializer(:user, :size_stat_consent_grow) do
    object.user_size_stat.consent_grow
  end
  add_to_serializer(:user, :size_stat_consent_shrink) do
    object.user_size_stat.consent_shrink
  end
  add_to_serializer(:user, :size_stat_character_upload_id) do
    object.user_size_stat.character_upload_id
  end
  add_to_serializer(:user, :size_stat_growth_rate) do
    object.user_size_stat.growth_rate
  end
  add_to_serializer(:user, :size_stat_ranking_public) do
    object.user_size_stat.ranking_public
  end

  # Include it for other important serializers
  %i[user_card].each do |serializer|
    add_to_serializer(serializer, :size_stat_current_size) do
      object.user_size_stat.current_size
    end
    add_to_serializer(serializer, :size_stat_is_changing) do
      object.user_size_stat.base_size != object.user_size_stat.target_size
    end
    add_to_serializer(serializer, :size_stat_ranking_public) do
      object.user_size_stat.ranking_public
    end
    add_to_serializer(serializer, :size_stat_character_upload_id) do
      object.user_size_stat.character_upload_id
    end

    add_to_serializer(serializer, :size_stat_ranking) do
      stat = object.user_size_stat
      return nil unless stat.ranking_public

      current = stat.current_size

      if current <= SiteSetting.size_smallest_ranking_threshold
        rank =
          UserSizeStat
            .joins(:user)
            .where("users.active = true AND users.suspended_at IS NULL")
            .where("target_size < ?", stat.target_size)
            .count + 1
        if rank == 1
          "Forum's smallest user"
        else
          "##{rank} smallest"
        end
      elsif current >= SiteSetting.size_largest_ranking_threshold
        rank =
          UserSizeStat
            .joins(:user)
            .where("users.active = true AND users.suspended_at IS NULL")
            .where("target_size > ?", stat.target_size)
            .count + 1
        if rank == 1
          "Forum's largest user"
        else
          "##{rank} largest"
        end
      else
        nil
      end
    end
  end

  on(:post_created) do |post, opts, user|
    next unless SiteSetting.size_plugin_enabled
    next if post.actor.system_user?

    author = post.user || user || post.actor
    next unless author

    stat = author.user_size_stat

    points_to_award =
      if post.is_first_post?
        SiteSetting.size_points_per_post
      else
        SiteSetting.size_points_per_reply
      end

    stat.update!(points: stat.points + points_to_award)
  end

  on(:invite_redeemed) do |invite_redeemed|
    next unless SiteSetting.size_plugin_enabled

    inviter = invite_redeemed.invite.invited_by
    invitee = invite_redeemed.user

    if inviter
      inviter_stat = inviter.user_size_stat
      inviter_stat.update!(points: inviter_stat.points + SiteSetting.size_points_invite_inviter)
    end

    if invitee
      invitee_stat = invitee.user_size_stat
      invitee_stat.update!(points: invitee_stat.points + SiteSetting.size_points_invite_invitee)
    end
  end
end
