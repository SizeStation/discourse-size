# frozen_string_literal: true

module DiscourseSize
  class RoleplaysController < ::ApplicationController
    requires_plugin DiscourseSize::PLUGIN_NAME
    before_action :ensure_logged_in

    def index
      roleplay_ids = DiscourseSizeRoleplayMember.joins(:character).where(discourse_size_characters: { user_id: current_user.id }).select(:roleplay_id)
      
      roleplays = DiscourseSizeRoleplay.where(creator_id: current_user.id)
        .or(DiscourseSizeRoleplay.where(id: roleplay_ids))
      
      roleplays = roleplays.order(created_at: :desc).distinct
      render json: { roleplays: serialize_data(roleplays, RoleplaySerializer) }
    end

    def show
      roleplay = find_roleplay
      
      # For private roleplays, only creator or members (including pending) can see
      unless roleplay.is_public || roleplay.creator_id == current_user.id || current_user.admin?
        is_member = DiscourseSizeRoleplayMember.joins(:character)
          .where(roleplay_id: roleplay.id, discourse_size_characters: { user_id: current_user.id })
          .exists?
        raise Discourse::InvalidAccess unless is_member
      end

      render json: { roleplay: serialize_data(roleplay, RoleplaySerializer) }
    end

    def remove_member
      roleplay = find_roleplay
      member = roleplay.discourse_size_roleplay_members.find(params[:member_id])
      
      # Either roleplay creator or character owner can remove
      raise Discourse::InvalidAccess unless roleplay.creator_id == current_user.id || 
                                          member.character.user_id == current_user.id || 
                                          current_user.admin?
      
      member.destroy
      render json: success_json
    end

    def create
      roleplay = DiscourseSizeRoleplay.new(roleplay_params.merge(creator_id: current_user.id))
      if roleplay.save
        render json: { roleplay: serialize_data(roleplay, RoleplaySerializer) }
      else
        render json: failed_json.merge(errors: roleplay.errors.full_messages), status: :unprocessable_content
      end
    end

    def update
      roleplay = find_roleplay
      raise Discourse::InvalidAccess unless roleplay.creator_id == current_user.id || current_user.admin?

      if roleplay.update(roleplay_params)
        render json: { roleplay: serialize_data(roleplay, RoleplaySerializer) }
      else
        render json: failed_json.merge(errors: roleplay.errors.full_messages), status: :unprocessable_content
      end
    end

    def destroy
      roleplay = find_roleplay
      raise Discourse::InvalidAccess unless roleplay.creator_id == current_user.id || current_user.admin?

      roleplay.destroy
      render json: success_json
    end

    def join
      roleplay = find_roleplay
      character = DiscourseSizeCharacter.find(params[:character_id])
      raise Discourse::InvalidAccess unless character.user_id == current_user.id

      unless roleplay.discourse_size_roleplay_members.exists?(character_id: character.id)
        roleplay.discourse_size_roleplay_members.create!(character_id: character.id, status: 'accepted')
      end

      render json: { roleplay: serialize_data(roleplay.reload, RoleplaySerializer) }
    end

    def invite
      roleplay = find_roleplay
      character = DiscourseSizeCharacter.find(params[:character_id])
      
      raise Discourse::InvalidAccess unless roleplay.creator_id == current_user.id || current_user.admin?

      # Check if current user has blocked/muted target user
      target_user = character.user
      if MutedUser.where(user_id: current_user.id, muted_user_id: target_user.id).exists? ||
         IgnoredUser.where(user_id: current_user.id, ignored_user_id: target_user.id).exists?
        return render json: failed_json.merge(errors: [I18n.t("discourse_size.roleplays.errors.user_blocked_by_you")]), status: :forbidden
      end

      # Check if target user has blocked/muted current user
      if MutedUser.where(user_id: target_user.id, muted_user_id: current_user.id).exists? ||
         IgnoredUser.where(user_id: target_user.id, ignored_user_id: current_user.id).exists?
        return render json: failed_json.merge(errors: [I18n.t("discourse_size.roleplays.errors.user_blocking")]), status: :forbidden
      end

      unless roleplay.discourse_size_roleplay_members.exists?(character_id: character.id)
        roleplay.discourse_size_roleplay_members.create!(character_id: character.id, status: 'pending')
        
        DiscourseSize::NotificationManager.send_roleplay_invite(roleplay, character)
      end

      render json: success_json
    end

    def accept_invite
      member = DiscourseSizeRoleplayMember.find_by(roleplay_id: find_roleplay.id, character_id: params[:character_id], status: 'pending')
      raise Discourse::NotFound unless member
      raise Discourse::InvalidAccess unless member.character.user_id == current_user.id

      member.update!(status: 'accepted')
      render json: success_json
    end

    def decline_invite
      member = DiscourseSizeRoleplayMember.find_by(roleplay_id: find_roleplay.id, character_id: params[:character_id], status: 'pending')
      raise Discourse::NotFound unless member
      raise Discourse::InvalidAccess unless member.character.user_id == current_user.id

      member.destroy
      render json: success_json
    end

    def leave
      roleplay = find_roleplay
      character = DiscourseSizeCharacter.find(params[:character_id])
      raise Discourse::InvalidAccess unless character.user_id == current_user.id

      roleplay.discourse_size_roleplay_members.where(character_id: character.id).destroy_all

      render json: success_json
    end

    private

    def find_roleplay
      DiscourseSizeRoleplay.find_by(uuid: params[:id]) || DiscourseSizeRoleplay.find_by(id: params[:id]) || (raise Discourse::NotFound)
    end

    def roleplay_params
      params.permit(:name, :description, :is_public, :picture)
    end
    
    def serialize_data(data, serializer)
      ::ActiveModel::ArraySerializer.new(data, each_serializer: serializer, scope: guardian, root: false).as_json
    rescue
      serializer.new(data, scope: guardian, root: false).as_json
    end
  end
end
