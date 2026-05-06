import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import I18n from "I18n";
import {
  formatSize,
  getComparison,
  getGrowthComparison,
} from "../lib/size-formatter";
import {
  calculateSize,
  isAnimating,
  getTimeRemaining,
} from "../lib/size-calculator";

export default class DiscourseSizeCharacterDetails extends Component {
  @service siteSettings;
  @service currentUser;
  @service modal;

  @tracked _currentTime = new Date();
  _timer = null;

  constructor() {
    super(...arguments);
    this._timer = setInterval(() => {
      if (this.isAnimating) {
        this._currentTime = new Date();
      }
    }, 33);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this._timer) clearInterval(this._timer);
  }

  get calculatedSizeCm() {
    return calculateSize(this.args.character, this._currentTime);
  }

  get formattedSize() {
    const system =
      this.currentUser?.discourse_size_measurement_system || "imperial";
    return formatSize(this.calculatedSizeCm, system);
  }

  get comparisonText() {
    const tempChar = Object.assign({}, this.args.character, {
      current_size: this.calculatedSizeCm,
    });
    return getComparison(tempChar);
  }

  get growthComparisonText() {
    return getGrowthComparison(this.args.character, this.calculatedSizeCm);
  }

  get canEdit() {
    return this.args.isCurrentUser || this.currentUser?.admin;
  }

  get showActions() {
    if (!this.currentUser) return false;
    const char = this.args.character;
    if (!char) return false;

    // Owner and admin can always see actions
    if (this.currentUser.id === char.user_id || this.currentUser.admin) {
      return true;
    }

    // Freeform characters only allow owner/admin to take actions
    if (char.character_type === "freeform") return false;

    // Show actions for everyone logged in (the component handles the blocked button)
    return true;
  }

  get canSeeBlockedStatus() {
    if (!this.currentUser) return false;
    const char = this.args.character;
    return this.currentUser.id === char?.user_id || this.currentUser.admin;
  }

  get isAnimating() {
    return isAnimating(this.args.character, this._currentTime);
  }

  get timeRemaining() {
    return getTimeRemaining(this.args.character, this._currentTime);
  }

  get activeAction() {
    const c = this.args.character;
    if (!c || !c.actions) return null;
    const now = this._currentTime;
    return (c.actions || []).find((a) => {
      if (!a.start_time || !a.end_time) return false;
      const start = new Date(a.start_time);
      const end = new Date(a.end_time);
      return now >= start && now < end;
    });
  }

  get progressPercent() {
    const activeAction = this.activeAction;
    if (!activeAction) return 0;

    const now = this._currentTime;
    const startT = new Date(activeAction.start_time);
    const endT = new Date(activeAction.end_time);
    const total = endT - startT;
    if (total <= 0) return 100;

    return Math.min(
      100,
      Math.max(0, Math.round(((now - startT) / total) * 100))
    );
  }

  get targetSizeCm() {
    return (
      parseFloat(this.args.character.base_size) +
      parseFloat(this.args.character.target_offset)
    );
  }

  get formattedTargetSize() {
    const system =
      this.currentUser?.discourse_size_measurement_system || "imperial";
    return formatSize(this.targetSizeCm, system);
  }

  @action
  async blockUser(user) {
    if (
      !confirm(
        I18n.t("discourse_size.blocking.confirm_block_user", {
          username: user.username,
        })
      )
    )
      return;

    try {
      const result = await ajax(
        `/size/characters/${this.args.character.id}/block_user`,
        {
          type: "POST",
          data: { user_id: user.id },
        }
      );
      if (result.character) this.args.onAction?.(result.character);
    } catch (e) {
      alert("Error blocking user");
    }
  }

  @action
  async unblockUser(user) {
    if (
      !confirm(
        I18n.t("discourse_size.blocking.confirm_unblock_user", {
          username: user.username,
        })
      )
    )
      return;

    try {
      const result = await ajax(
        `/size/characters/${this.args.character.id}/unblock_user`,
        {
          type: "POST",
          data: { user_id: user.id },
        }
      );
      if (result.character) this.args.onAction?.(result.character);
    } catch (e) {
      alert("Error unblocking user");
    }
  }

  @action
  async deleteAction(actionEntry) {
    if (!confirm(I18n.t("discourse_size.point_history.confirm_delete"))) return;

    try {
      const result = await ajax(`/size/actions/${actionEntry.id}`, {
        type: "DELETE",
      });
      if (result.character) this.args.onAction?.(result.character);
    } catch (e) {
      alert("Error deleting action");
    }
  }

  @action
  async setMain() {
    try {
      await ajax(`/size/characters/${this.args.character.id}/set_main`, {
        type: "POST",
      });
      this.args.onAction?.();
    } catch (e) {
      alert("Error setting main character");
    }
  }
}
