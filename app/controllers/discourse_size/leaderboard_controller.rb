# frozen_string_literal: true

module DiscourseSize
  class LeaderboardController < ::ApplicationController
    requires_plugin DiscourseSize::PLUGIN_NAME

    def index
      limit = params[:limit] || 50
      search = params[:search].to_s.strip

      characters =
        DiscourseSizeCharacter
          .includes(:user)
          .where(character_type: "game")

      if search.present?
        # Safe ILIKE search for postgres
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

      characters = characters.order(name: :asc).limit(limit)

      respond_to do |format|
        format.html { render "default/empty" }
        format.json { render json: { characters: characters.map { |c| character_serializer(c) } } }
      end
    end

    private

    def character_serializer(c)
      c.sync_offset!
      seconds_left = c.time_remaining_seconds
      
      # Determine preferences based on blocked items. 
      # Since we don't pass a user, we check directly against the blocked lists for 'grow' and 'shrink'
      prefers_growing = !c.blocked_item_keys.include?("__all_growing__") && !c.blocked_item_keys.include?("__all__")
      prefers_shrinking = !c.blocked_item_keys.include?("__all_shrinking__") && !c.blocked_item_keys.include?("__all__")

      {
        id: c.id,
        user_id: c.user_id,
        name: c.name,
        picture: c.picture,
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
