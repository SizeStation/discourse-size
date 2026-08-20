import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class DiscourseSizeInvitedCharacters extends Component {
  get pendingMembers() {
    return (this.args.model.roleplay?.members || []).filter(
      (m) => m.status === "pending"
    );
  }

  @action
  async removeInvite(member) {
    if (!confirm(i18n("discourse_size.roleplays.confirm_remove_invite"))) {
      return;
    }

    try {
      await ajax(
        `/size/roleplays/${this.args.model.roleplay.id}/remove_member`,
        {
          type: "POST",
          data: { member_id: member.id },
        }
      );
      this.args.model.onUpdate();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <DModal
      @title={{i18n "discourse_size.roleplays.pending_invites"}}
      @closeModal={{@closeModal}}
      class="discourse-size-invited-characters-modal"
    >
      <:body>
        <div class="invited-characters-content">
          {{#if this.pendingMembers.length}}
            <div class="invites-list">
              {{#each this.pendingMembers as |member|}}
                <div class="invite-item">
                  <div class="char-thumb">
                    {{#if member.character.picture}}
                      <img src={{member.character.picture}} alt />
                    {{else}}
                      {{icon "user"}}
                    {{/if}}
                  </div>
                  <div class="char-details">
                    <span class="name">{{member.character.name}}</span>
                    <span class="owner">@{{member.character.username}}</span>
                  </div>
                  <DButton
                    @action={{fn this.removeInvite member}}
                    @icon="trash-can"
                    class="btn-danger btn-small"
                    @title={{i18n "discourse_size.cancel"}}
                  />
                </div>
              {{/each}}
            </div>
          {{else}}
            <p class="no-invites">{{i18n
                "discourse_size.roleplays.modals.invite.no_results"
              }}</p>
          {{/if}}
        </div>
      </:body>
    </DModal>
  </template>
}
