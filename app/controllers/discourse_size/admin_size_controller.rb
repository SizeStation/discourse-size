# frozen_string_literal: true

module ::DiscourseSize
  class AdminSizeController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_admin

    def override_user
      username = params[:username]
      target_size = params[:target_size]
      growth_rate = params[:growth_rate]
      points = params[:points]

      user = User.find_by_username(username)
      raise Discourse::NotFound unless user

      stat = user.user_size_stat

      updates = {}
      if target_size
        updates[:target_size] = target_size.to_f
        # When an admin forces a target size, we usually want to snap them to it immediately, so we reset base_size too.
        updates[:base_size] = target_size.to_f
        updates[:size_updated_at] = Time.zone.now
      end

      updates[:growth_rate] = growth_rate.to_f if growth_rate
      updates[:points] = points.to_i if points

      stat.update!(updates)

      render json: success_json
    end
  end
end
