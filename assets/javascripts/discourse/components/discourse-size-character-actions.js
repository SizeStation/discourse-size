import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { formatSize } from "../lib/size-formatter";
import DiscourseSizeUseItem from "./modal/discourse-size-use-item";

export default class DiscourseSizeCharacterActions extends Component {
  @service siteSettings;
  @service currentUser;

  @service modal;
  @tracked amountInput = 10;
  @tracked boostAmountInput = 10;
  @tracked manualSizeInput = "";

  constructor() {
    super(...arguments);
    if (this.args.character.character_type === "freeform" || this.args.character.character_type === "roleplay") {
      this.manualSizeInput = (
        this.args.character.current_size || this.args.character.base_size
      ).toString();
    }
  }

  @action
  openInventoryModal() {
    this.modal.show(DiscourseSizeUseItem, {
      model: {
        character: this.args.character,
        onAction: this.args.onAction,
      },
    });
  }

  get isGame() {
    return this.args.character.character_type === "game";
  }

  get isFreeform() {
    return this.args.character.character_type === "freeform";
  }

  get isRoleplay() {
    return this.args.character.character_type === "roleplay";
  }

  get isManual() {
    return this.isFreeform || this.isRoleplay;
  }

  get canEdit() {
    return this.args.isCurrentUser || this.currentUser?.admin;
  }

  get isBlocked() {
    if (!this.currentUser) return false;
    const char = this.args.character;
    if (!char) return false;

    // Owner and admin are never blocked
    if (this.currentUser.id === char.user_id || this.currentUser.admin) {
      return false;
    }

    // Check if user is blocked
    const currentUserId = Number(this.currentUser.id);
    if (
      char.blocked_user_ids?.map((id) => Number(id)).includes(currentUserId)
    ) {
      return true;
    }

    // Check if all interactions are blocked
    if (char.blocked_item_keys?.includes("__all__")) return true;

    return false;
  }

  get canSeeBlockedStatus() {
    if (!this.currentUser) return false;
    const char = this.args.character;
    return this.currentUser.id === char?.user_id || this.currentUser.admin;
  }

  @action
  setManualSize(event) {
    this.manualSizeInput = event.target.value;
  }

  @action
  async setSize() {
    const size = parseFloat(this.manualSizeInput);
    if (isNaN(size)) return;

    try {
      const result = await ajax(
        `/size/characters/${this.args.character.id}/set_size`,
        {
          type: "POST",
          data: { size },
        }
      );
      this.args.onAction?.(result);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async runTrigger(triggerName) {
    try {
      const result = await ajax(
        `/size/characters/${this.args.character.id}/trigger`,
        {
          type: "POST",
          data: { trigger_name: triggerName },
        }
      );
      this.args.onAction?.(result);
    } catch (e) {
      popupAjaxError(e);
    }
  }
}
