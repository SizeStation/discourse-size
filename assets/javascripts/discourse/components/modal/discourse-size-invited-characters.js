import Component from "@glimmer/component";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";

export default class DiscourseSizeInvitedCharacters extends Component {
  get pendingMembers() {
    return (this.args.model.roleplay?.members || []).filter(m => m.status === 'pending');
  }

  @action
  async removeInvite(member) {
    if (!confirm(I18n.t("discourse_size.roleplays.confirm_remove_invite"))) return;

    try {
      await ajax(`/size/roleplays/${this.args.model.roleplay.id}/remove_member`, {
        type: "POST",
        data: { member_id: member.id }
      });
      this.args.model.onUpdate();
    } catch (e) {
      popupAjaxError(e);
    }
  }
}
