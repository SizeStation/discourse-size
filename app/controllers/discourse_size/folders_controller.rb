# frozen_string_literal: true

module DiscourseSize
  class FoldersController < ::ApplicationController
    requires_plugin DiscourseSize::PLUGIN_NAME
    before_action :ensure_logged_in

    def create
      folder = DiscourseSizeFolder.new(folder_params)
      folder.user_id = params[:user_id] || current_user.id

      # Authorization
      guardian.ensure_can_edit_user!(User.find(folder.user_id))

      # Put at bottom
      max_pos = DiscourseSizeFolder.where(user_id: folder.user_id).maximum(:position) || 0
      folder.position = max_pos + 1

      if folder.save
        render_serialized(folder, FolderSerializer)
      else
        render_json_error(folder)
      end
    end

    def update
      folder = DiscourseSizeFolder.find(params[:id])
      guardian.ensure_can_edit_user!(folder.user)

      if folder.update(folder_params)
        render_serialized(folder, FolderSerializer)
      else
        render_json_error(folder)
      end
    end

    def destroy
      folder = DiscourseSizeFolder.find(params[:id])
      guardian.ensure_can_edit_user!(folder.user)

      folder.destroy
      render json: success_json
    end

    def reorder
      user_id = params[:user_id] || current_user.id
      guardian.ensure_can_edit_user!(User.find(user_id))

      DiscourseSizeFolder.reorder(User.find(user_id), params[:mapping])
      render json: success_json
    end

    private

    def folder_params
      params.require(:folder).permit(:name)
    end
  end
end
