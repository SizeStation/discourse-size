# frozen_string_literal: true

module ::MyPluginModule
  class SizeController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_logged_in
    before_action :ensure_staff, only: %i[admin_set_points admin_set_size]

    def give_points
      target = fetch_target_user
      amount = params.require(:amount).to_i

      if amount <= 0
        return render_json_error(I18n.t("discourse_size.invalid_amount"))
      end

      begin
        ::DiscourseSize.transfer_points!(from_user: current_user, to_user: target, amount: amount)
      rescue Discourse::InvalidAccess => e
        return render_json_error(e.message)
      rescue Discourse::InvalidParameters => e
        return render_json_error(e.message)
      end

      render_json_dump(
        from_points: ::DiscourseSize.points_for(current_user),
        to_points: ::DiscourseSize.points_for(target),
      )
    end

    def change_size
      percent = params.require(:percent).to_i
      if percent == 0
        return render_json_error(I18n.t("discourse_size.invalid_percent"))
      end

      begin
        ::DiscourseSize.change_size_with_points!(current_user, percent)
      rescue Discourse::InvalidAccess => e
        return render_json_error(e.message)
      rescue Discourse::InvalidParameters => e
        return render_json_error(e.message)
      end

      render_json_dump(
        size_cm: ::DiscourseSize.size_cm_for(current_user),
        size_display: ::DiscourseSize.formatted_size_for(current_user),
        size_points: ::DiscourseSize.points_for(current_user),
      )
    end

    def admin_set_points
      target = fetch_target_user
      points = params.require(:points).to_i

      ::DiscourseSize.set_points!(target, points)

      render_json_dump(
        points: ::DiscourseSize.points_for(target),
      )
    end

    def admin_set_size
      target = fetch_target_user
      size_cm = params.require(:size_cm).to_i

      ::DiscourseSize.set_size_cm!(target, size_cm)

      render_json_dump(
        size_cm: ::DiscourseSize.size_cm_for(target),
        size_display: ::DiscourseSize.formatted_size_for(target),
      )
    end

    private

    def fetch_target_user
      username = params[:target_username] || params[:username]
      raise Discourse::InvalidParameters.new(:username) if username.blank?

      User.find_by_username!(username)
    end
  end
end
