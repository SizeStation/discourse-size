import { fn } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import { eq, or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import DiscourseSizeCharacterCard from "../components/discourse-size-character-card";

export default RouteTemplate(
  <template>
    <div class="size-roleplay-detail">
      <div
        class="rp-header {{if @controller.roleplay.picture 'has-picture'}}"
        style={{@controller.headerStyle}}
      >
        <div class="rp-header-content">
          <h1>{{@controller.roleplay.name}}</h1>
          <div class="rp-creator">
            {{i18n
              "discourse_size.roleplays.created_by"
              username=@controller.roleplay.creator_username
            }}
          </div>
          <p>{{@controller.roleplay.description}}</p>

          <div class="rp-header-actions">
            <DButton
              @action={{@controller.copyLink}}
              @icon="link"
              @label="discourse_size.roleplays.copy_link"
              class="btn-default"
            />
            {{#if @controller.isCreator}}
              <DButton
                @action={{@controller.editRoleplay}}
                @icon="pencil"
                @label="discourse_size.edit"
                class="btn-default"
              />
              <DButton
                @action={{@controller.openInviteModal}}
                @label="discourse_size.roleplays.invite"
                @icon="plus"
                class="btn-default"
              />
              {{#if @controller.allPendingInvites.length}}
                <DButton
                  @action={{@controller.openInvitedModal}}
                  @icon="envelope"
                  class="btn-default"
                >
                  {{i18n "discourse_size.roleplays.pending_invites"}}
                  <span
                    class="badge-number"
                  >{{@controller.allPendingInvites.length}}</span>
                </DButton>
              {{/if}}
              <DButton
                @action={{@controller.deleteRoleplay}}
                @icon="trash-can"
                @label="discourse_size.delete"
                class="btn-danger"
              />
            {{else}}
              {{#if @controller.roleplay.is_public}}
                <DButton
                  @action={{@controller.joinRoleplay}}
                  @label="discourse_size.roleplays.join"
                  @icon="user-plus"
                  class="btn-default"
                />
              {{/if}}
            {{/if}}
          </div>
        </div>
      </div>

      {{#if @controller.myPendingInvites.length}}
        <div class="my-pending-invites">
          <div class="invited-header">
            {{icon "envelope"}}
            <h2>{{i18n "discourse_size.roleplays.invited_heading"}}</h2>
          </div>
          <div class="invited-body">
            {{#each @controller.myPendingInvites as |member|}}
              <div class="my-invite-item">
                <div class="invite-char">
                  {{#if member.character.picture}}
                    <img src={{member.character.picture}} class="char-pic" />
                  {{else}}
                    <div class="char-pic-placeholder">{{icon "user"}}</div>
                  {{/if}}
                  <div class="char-info">
                    <span class="name">{{member.character.name}}</span>
                    <span class="hint">{{i18n
                        "discourse_size.roleplays.invited_hint"
                      }}</span>
                  </div>
                </div>
                <div class="invite-actions">
                  <DButton
                    @action={{fn @controller.acceptInvite member}}
                    @icon="check"
                    @label="discourse_size.roleplays.accept_invite"
                    class="btn-primary"
                  />
                  <DButton
                    @action={{fn @controller.declineInvite member}}
                    @icon="xmark"
                    @label="discourse_size.roleplays.decline_invite"
                    class="btn-danger"
                  />
                </div>
              </div>
            {{/each}}
          </div>
        </div>
      {{/if}}

      <div class="rp-members-section">
        {{#each @controller.acceptedMembers as |member|}}
          <div class="member-card-wrapper">
            <DiscourseSizeCharacterCard
              @character={{member.effectiveCharacter}}
              @isCurrentUser={{eq
                member.character.user_id
                @controller.currentUser.id
              }}
              @userPoints={{@controller.currentUser.discourse_size_points}}
              @onAction={{@controller.refreshRoleplay}}
              @onUpdate={{fn @controller.editCharacter member}}
            />
            {{#if
              (or
                @controller.isCreator
                (eq member.character.user_id @controller.currentUser.id)
              )
            }}
              <div class="member-actions">
                <DButton
                  @action={{fn @controller.removeMember member}}
                  @icon="trash-can"
                  class="btn-danger btn-small"
                  @title={{i18n "discourse_size.roleplays.leave"}}
                />
              </div>
            {{/if}}
          </div>
        {{/each}}
      </div>
    </div>
  </template>
);
