# frozen_string_literal: true

module DiscourseSize
  class LeaderboardController < ::ApplicationController
    requires_plugin DiscourseSize::PLUGIN_NAME

    def index
      limit = [(params[:limit] || 100).to_i, 100].min
      offset = (params[:offset] || 0).to_i
      search = params[:search].to_s.strip

      characters =
        DiscourseSizeCharacter
          .includes(:user)
          .where(character_type: "game")

      if search.present?
        characters = characters.where("name ILIKE ?", "%#{search}%")
      end

      preference = params[:preference].to_s.strip
      if preference == "both"
        characters = characters.where("NOT (blocked_item_keys ? '__all_growing__') AND NOT (blocked_item_keys ? '__all_shrinking__') AND NOT (blocked_item_keys ? '__all__')")
      elsif preference == "growing"
        characters = characters.where("NOT (blocked_item_keys ? '__all_growing__') AND NOT (blocked_item_keys ? '__all__') AND (blocked_item_keys ? '__all_shrinking__')")
      elsif preference == "shrinking"
        characters = characters.where("NOT (blocked_item_keys ? '__all_shrinking__') AND NOT (blocked_item_keys ? '__all__') AND (blocked_item_keys ? '__all_growing__')")
      elsif preference == "neither"
        characters = characters.where("blocked_item_keys ? '__all__' OR (blocked_item_keys ? '__all_growing__' AND blocked_item_keys ? '__all_shrinking__')")
      end

      total = characters.count
      characters = characters.order(name: :asc).offset(offset).limit(limit + 1)
      more = characters.length > limit
      characters = characters.limit(limit)

      respond_to do |format|
        format.html { render "default/empty" }
        format.json { render json: { characters: characters.map { |c| character_serializer(c) }, total: total, more: more } }
      end
    end

    private

    def character_serializer(c)
      c.sync_offset!
      seconds_left = c.time_remaining_seconds

      keys = c.blocked_item_keys
      full_block = keys.include?("__all__")
      grow_blocked = keys.include?("__all_growing__") || full_block
      shrink_blocked = keys.include?("__all_shrinking__") || full_block

      prefers_growing = !grow_blocked
      prefers_shrinking = !shrink_blocked

      # When both are fully blocked → neither
      # When one is fully blocked and the other is partially → prefer the unblocked one
      if grow_blocked && shrink_blocked
        prefers_growing = false
        prefers_shrinking = false
      elsif grow_blocked
        prefers_growing = false
        prefers_shrinking = true
      elsif shrink_blocked
        prefers_growing = true
        prefers_shrinking = false
      end

      {
        id: c.id,
        user_id: c.user_id,
        name: c.name,
        picture: c.picture,
        base_size: c.base_size,
        prefers_growing: prefers_growing,
        prefers_shrinking: prefers_shrinking,
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
