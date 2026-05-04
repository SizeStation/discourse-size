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

      render json: { characters: characters.map { |c| character_serializer(c) } }
    end

    private

    def character_serializer(c)
      c.sync_offset!

      {
        id: c.id,
        user_id: c.user_id,
        name: c.name,
        picture: c.picture,
        current_size: c.current_size,
        measurement_system: c.measurement_system,
        user: {
          id: c.user.id,
          username: c.user.username,
          avatar_template: c.user.avatar_template,
        },
      }
    end
  end
end
