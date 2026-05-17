import Controller from "@ember/controller";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseSizeJoinRoleplay from "../components/modal/discourse-size-join-roleplay";
import DiscourseSizeInviteToRoleplay from "../components/modal/discourse-size-invite-to-roleplay";
import DiscourseSizeCreateRoleplay from "../components/modal/discourse-size-create-roleplay";
import DiscourseSizeEditCharacter from "../components/modal/discourse-size-edit-character";
import DiscourseSizeInvitedCharacters from "../components/modal/discourse-size-invited-characters";
import I18n from "I18n";

export default class SizeRoleplayController extends Controller {
  @service modal;
  @service currentUser;
  @service router;
  @tracked roleplay = null;

  get headerStyle() {
    if (this.roleplay?.picture) {
      return htmlSafe(`background-image: linear-gradient(rgba(0,0,0,0.6), rgba(0,0,0,0.6)), url(${this.roleplay.picture});`);
    }
    return "";
  }

  get acceptedMembers() {
    return (this.roleplay?.members || []).filter(m => m.status === 'accepted');
  }

  get myPendingInvites() {
    return (this.roleplay?.members || []).filter(
      (m) => m.status === "pending" && m.character.user_id === this.currentUser.id
    );
  }

  get allPendingInvites() {
    return (this.roleplay?.members || []).filter(m => m.status === 'pending');
  }

  get isCreator() {
    return this.roleplay?.creator_id === this.currentUser.id || this.currentUser.admin;
  }

  @action
  joinRoleplay() {
    this.modal.show(DiscourseSizeJoinRoleplay, {
      model: {
        roleplay: this.roleplay,
        onJoin: (updatedRp) => {
          this.roleplay = updatedRp;
        },
      },
    });
  }

  @action
  openInviteModal() {
    this.modal.show(DiscourseSizeInviteToRoleplay, {
      model: {
        roleplay: this.roleplay,
        onInvite: () => {
          this.send("reloadModel");
        }
      }
    });
  }

  @action
  openInvitedModal() {
    // We'll need a new modal for this
    this.modal.show(DiscourseSizeInvitedCharacters, {
      model: {
        roleplay: this.roleplay,
        onUpdate: () => this.send("reloadModel")
      }
    });
  }

  @action
  async removeMember(member) {
    if (!confirm(I18n.t("discourse_size.roleplays.confirm_remove"))) return;
    
    try {
      await ajax(`/size/roleplays/${this.roleplay.id}/remove_member`, {
        type: "POST",
        data: { member_id: member.id }
      });
      this.send("reloadModel");
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async deleteRoleplay() {
    if (!confirm(I18n.t("discourse_size.roleplays.confirm_delete"))) return;

    try {
      await ajax(`/size/roleplays/${this.roleplay.id}`, {
        type: "DELETE"
      });
      this.router.transitionTo("user.characters", this.currentUser.username);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  copyLink() {
    const url = `${window.location.origin}/size/roleplays/${this.roleplay.uuid}`;
    navigator.clipboard.writeText(url).then(() => {
      alert(I18n.t("discourse_size.roleplays.link_copied"));
    });
  }

  @action
  editRoleplay() {
    this.modal.show(DiscourseSizeCreateRoleplay, {
      model: {
        roleplay: this.roleplay,
        onSave: (updatedRp) => {
          this.roleplay = updatedRp;
        }
      }
    });
  }

  @action
  async acceptInvite(member) {
    try {
      await ajax(`/size/roleplays/${this.roleplay.id}/accept_invite`, {
        type: "POST",
        data: { character_id: member.character_id },
      });
      this.send("reloadModel");
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async declineInvite(member) {
    try {
      await ajax(`/size/roleplays/${this.roleplay.id}/decline_invite`, {
        type: "POST",
        data: { character_id: member.character_id },
      });
      
      // If private and no longer invited/member, we must redirect
      if (!this.roleplay.is_public) {
        this.router.transitionTo("size.roleplays");
      } else {
        this.send("reloadModel");
      }
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  refreshRoleplay() {
    this.send("reloadModel");
  }

  @action
  editCharacter(character) {
    this.modal.show(DiscourseSizeEditCharacter, {
      model: {
        character,
        onSave: () => {
          this.refreshRoleplay();
        },
      },
    });
  }
}
