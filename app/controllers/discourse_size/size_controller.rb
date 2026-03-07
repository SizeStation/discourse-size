# frozen_string_literal: true

module ::DiscourseSize
  class SizeController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login

    def update_preferences
      stat = current_user.user_size_stat
      stat.update!(
        measurement_system: params[:measurement_system] || stat.measurement_system,
        consent_grow: params[:consent_grow].nil? ? stat.consent_grow : params[:consent_grow],
        consent_shrink: params[:consent_shrink].nil? ? stat.consent_shrink : params[:consent_shrink],
        ranking_public: params[:ranking_public].nil? ? stat.ranking_public : params[:ranking_public],
      )
      render json: success_json
    end

    def upload_picture
      stat = current_user.user_size_stat
      stat.update!(character_upload_id: params[:upload_id])
      render json: success_json
    end

    def spend_points
      action = params[:action_type] # "grow" or "shrink"
      points = params[:points].to_i
      target_username = params[:target_username]

      raise Discourse::InvalidParameters.new(:points) if points <= 0

      stat = current_user.user_size_stat

      if stat.points < points
        return render json: { error: "Not enough points" }, status: :bad_request
      end

      if target_username.present?
        target_user = User.find_by_username(target_username)
      else
        target_user = current_user
      end
      
      return render json: { error: "User not found" }, status: :not_found unless target_user

      target_stat = target_user.user_size_stat

      if target_user.id != current_user.id
        if action == "grow" && !target_stat.consent_grow
          return render json: { error: "User does not consent to being grown" }, status: :bad_request
        end
        if action == "shrink" && !target_stat.consent_shrink
          return render json: { error: "User does not consent to being shrunk" }, status: :bad_request
        end
      end

      # Before applying new points, solidify the current size so calculations start from there.
      target_stat.dynamically_update_size!

      percent_per_point = SiteSetting.size_growth_percent_per_point
      total_percent_change = points * percent_per_point

      if action == "grow"
        change_multiplier = 1.0 + (total_percent_change / 100.0)
      else
        change_multiplier = 1.0 - (total_percent_change / 100.0)
      end

      # Ensure shrink doesn't go below something crazy like 0.0001 (1 micron)
      new_target = [target_stat.target_size * change_multiplier, 0.000001].max

      target_stat.update!(target_size: new_target)
      stat.update!(points: stat.points - points)

      render json: { success: true, new_target: new_target }
    end

    def compare
      targets = params[:targets] || []
      users = User.where(username: targets).includes(:user_size_stat)
      stats =
        users.map do |u|
          stat = u.user_size_stat
          {
            username: u.username,
            current_size: stat.current_size,
            upload_url:
              stat.character_upload_id ? Upload.find_by(id: stat.character_upload_id)&.url : u.avatar_template,
          }
        end
      render json: { targets: stats }
    end
  end
end
