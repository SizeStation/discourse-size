# frozen_string_literal: true

module DiscourseSize
  class LeaderboardController < ::ApplicationController
    requires_plugin DiscourseSize::PLUGIN_NAME

    def index
      direction = params[:sort] == "smallest" ? "ASC" : "DESC"
      direction = params[:sort] == "smallest" ? "ASC" : "DESC"
      limit = params[:limit] || 50

      # For sorting, we can use the calculated current_size, but in SQL we don't have it directly.
      # Because current_size = base_size + current_calculated_offset.
      # As a proxy, base_size + target_offset is exactly what they are moving towards.
      # To make it accurate, we could just sort by (base_size + current_offset)
      # But current_offset is updated lazily. We can either do a background job to sync them, or just use what we have in DB.

      # We'll use (base_size + current_offset) as sorting.
      characters =
        DiscourseSizeCharacter
          .includes(:user)
          .where(character_type: "game")
          .order(Arel.sql("(base_size + current_offset) #{direction}"))
          .limit(limit)

      respond_to do |format|
        format.html { render "default/empty" }
        format.json { render json: { characters: characters.map { |c| character_serializer(c) } } }
      end
    end

    private

    def character_serializer(c)
      c.sync_offset!
      target_size = c.base_size + c.target_offset
      seconds_left = c.time_remaining_seconds

      {
        id: c.id,
        user_id: c.user_id,
        name: c.name,
        picture: c.picture,
        current_size: c.current_size,
        target_size: target_size,
        measurement_system: c.measurement_system,
        is_animating: (c.current_offset - c.target_offset).abs > 0.0001,
        is_growing: c.target_offset > c.current_offset,
        time_remaining: (seconds_left && seconds_left > 0) ? format_duration(seconds_left) : nil,
        user: {
          id: c.user.id,
          username: c.user.username,
          avatar_template: c.user.avatar_template,
        },
      }
    end

    def format_duration(seconds)
      if seconds < 60
        "#{seconds.ceil}s"
      elsif seconds < 3600
        m = (seconds / 60).floor
        s = (seconds % 60).floor
        s > 0 ? "#{m}m #{s}s" : "#{m}m"
      elsif seconds < 86400
        h = (seconds / 3600).floor
        m = ((seconds % 3600) / 60).floor
        m > 0 ? "#{h}h #{m}m" : "#{h}h"
      else
        "#{(seconds / 86400.0).round(1)}d"
      end
    end
  end
end
