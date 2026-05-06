import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import {
  formatSize,
  getComparison,
  getGrowthComparison,
} from "../lib/size-formatter";
import DiscourseSizeGrowthGraph from "./modal/discourse-size-growth-graph";
import DiscourseSizeAdminEdit from "./modal/discourse-size-admin-edit";

export default class DiscourseSizeCharacterCard extends Component {
  @service currentUser;
  @service modal;
  @service siteSettings;

  @tracked _currentTime = new Date();
  @tracked amountInput = 1;

  _timer = null;

  constructor() {
    super(...arguments);
    this._timer = setInterval(() => {
      if (this.isAnimating) {
        this._currentTime = new Date();
      }
    }, 100);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this._timer) clearInterval(this._timer);
  }

  _activeActionAt(time) {
    const c = this.args?.character;
    if (!c || !Array.isArray(c.actions)) return null;

    return c.actions.find((a) => {
      if (!a.start_time || !a.end_time) return false;
      const start = new Date(a.start_time);
      const end = new Date(a.end_time);
      return time >= start && time < end;
    });
  }

  get calculatedSizeCm() {
    const c = this.args?.character;
    if (!c) return 0;

    const now = this._currentTime;
    const activeAction = this._activeActionAt(now);

    if (activeAction) {
      const startT = new Date(activeAction.start_time);
      const endT = new Date(activeAction.end_time);
      const totalDuration = endT.getTime() - startT.getTime();

      if (totalDuration > 0) {
        const elapsed = now.getTime() - startT.getTime();
        const progress = elapsed / totalDuration;

        const startOff = parseFloat(activeAction.start_offset);
        const endOff = parseFloat(activeAction.end_offset);

        const currentOffset = startOff + (endOff - startOff) * progress;
        return parseFloat(c.base_size) + currentOffset;
      } else {
        return parseFloat(c.base_size) + parseFloat(activeAction.end_offset);
      }
    }

    const nextAction = c.actions
      .slice()
      .filter((a) => a.start_time && new Date(a.start_time) > now)
      .sort((a, b) => new Date(a.start_time) - new Date(b.start_time))[0];

    if (nextAction) {
      return parseFloat(c.base_size) + parseFloat(nextAction.start_offset);
    }

    return parseFloat(c.base_size) + parseFloat(c.target_offset);
  }

  get formattedSize() {
    return formatSize(
      this.calculatedSizeCm,
      this.args?.character?.measurement_system
    );
  }

  get comparisonText() {
    const tempChar = Object.assign({}, this.args?.character, {
      current_size: this.calculatedSizeCm,
    });
    return getComparison(tempChar);
  }

  get growthComparisonText() {
    return getGrowthComparison(this.args?.character, this.calculatedSizeCm);
  }

  get targetSizeCm() {
    return (
      parseFloat(this.args?.character?.base_size) +
      parseFloat(this.args?.character?.target_offset)
    );
  }

  get formattedTargetSize() {
    return formatSize(
      this.targetSizeCm,
      this.args?.character?.measurement_system
    );
  }

  get isAnimating() {
    const c = this.args?.character;
    if (!c) return false;

    const now = this._currentTime;
    const lastAction = c.actions
      .slice()
      .filter((a) => a.end_time)
      .sort((a, b) => new Date(b.end_time) - new Date(a.end_time))[0];

    if (!lastAction) return false;
    return new Date(lastAction.end_time) > now;
  }

  get timeRemaining() {
    const c = this.args?.character;
    if (!c) return null;

    const now = this._currentTime;
    const lastAction = c.actions
      .slice()
      .filter((a) => a.end_time)
      .sort((a, b) => new Date(b.end_time) - new Date(a.end_time))[0];

    if (!lastAction || new Date(lastAction.end_time) <= now) return null;

    const seconds = Math.floor((new Date(lastAction.end_time) - now) / 1000);
    if (seconds <= 0) return null;

    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = seconds % 60;

    if (h > 0) return `${h}h ${m}m ${s}s`;
    if (m > 0) return `${m}m ${s}s`;
    return `${s}s`;
  }

  get progressPercent() {
    const c = this.args?.character;
    if (!c) return 0;

    const now = this._currentTime;
    const activeAction = this._activeActionAt(now);
    if (!activeAction) return 0;

    const startT = new Date(activeAction.start_time);
    const endT = new Date(activeAction.end_time);
    const total = endT - startT;
    if (total <= 0) return 100;

    return Math.min(100, Math.max(0, ((now - startT) / total) * 100));
  }

  get isGrowing() {
    const c = this.args?.character;
    if (!c) return false;
    const now = this._currentTime;
    const activeAction = this._activeActionAt(now);
    if (activeAction) {
      return (
        parseFloat(activeAction.end_offset) >
        parseFloat(activeAction.start_offset)
      );
    }
    return parseFloat(c.target_offset) > parseFloat(c.current_offset);
  }

  get formattedStartSize() {
    const c = this.args?.character;
    if (!c) return "";
    const now = this._currentTime;
    const activeAction = this._activeActionAt(now);
    if (!activeAction) return "";
    return formatSize(
      parseFloat(c.base_size) + parseFloat(activeAction.start_offset),
      c.measurement_system
    );
  }

  get hasDescription() {
    const c = this.args?.character;
    return c?.description || c?.info_post || c?.show_comparison;
  }

  get showActions() {
    if (!this.currentUser) return false;
    const char = this.args?.character;
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
    const char = this.args?.character;
    return this.currentUser.id === char?.user_id || this.currentUser.admin;
  }

  get recentActions() {
    return (this.args?.character?.actions || []).slice(0, 3);
  }

  @action
  showGrowthGraph() {
    this.modal.show(DiscourseSizeGrowthGraph, {
      model: {
        character: this.args?.character,
        onActionDeleted: (updatedChar) => {
          this.args?.onAction?.(updatedChar);
        },
      },
    });
  }

  @action
  async setMain() {
    try {
      await ajax(`/size/characters/${this.args?.character?.id}/set_main`, {
        type: "POST",
      });
      this.args?.onAction?.();
    } catch (e) {
      alert("Error setting main character");
    }
  }

  @action
  adminEdit() {
    this.modal.show(DiscourseSizeAdminEdit, {
      model: {
        character: this.args?.character,
        onSave: this.args?.onAction,
      },
    });
  }

  get canEdit() {
    return this.args?.isCurrentUser || this.currentUser?.admin;
  }
}
