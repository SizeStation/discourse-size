import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import {
  calculateSize,
  isAnimating,
  getTimeRemaining,
} from "../lib/size-calculator";
import {
  formatSize,
  getComparison,
  getGrowthComparison,
} from "../lib/size-formatter";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import DiscourseSizeGrowthGraph from "./modal/discourse-size-growth-graph";

export default class DiscourseSizeCharacterCard extends Component {
  @service currentUser;
  @service modal;
  @service siteSettings;

  @tracked _currentTime = new Date();
  _timer = null;

  constructor() {
    super(...arguments);
    this._timer = setInterval(() => {
      if (this.isAnimating) {
        this._currentTime = new Date();
      }
    }, 33); // ~30fps for smooth animation
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this._timer) {
      clearInterval(this._timer);
    }
  }

  get canEdit() {
    return this.args?.isCurrentUser || this.currentUser?.admin;
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

  get calculatedSizeCm() {
    return calculateSize(this.args?.character, this._currentTime);
  }

  get formattedSize() {
    const system =
      this.currentUser?.discourse_size_measurement_system || "imperial";
    return formatSize(this.calculatedSizeCm, system);
  }

  get targetSizeCm() {
    return (
      parseFloat(this.args?.character?.base_size) +
      parseFloat(this.args?.character?.target_offset)
    );
  }

  get formattedTargetSize() {
    const system =
      this.currentUser?.discourse_size_measurement_system || "imperial";
    return formatSize(this.targetSizeCm, system);
  }

  get formattedStartSize() {
    const system =
      this.currentUser?.discourse_size_measurement_system || "imperial";
    return formatSize(
      parseFloat(this.args?.character?.base_size) +
        parseFloat(this.args?.character?.start_offset),
      system
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

  get hasDescription() {
    const c = this.args?.character;
    return c?.description || c?.info_post || c?.show_comparison;
  }

  get isAnimating() {
    return isAnimating(this.args?.character, this._currentTime);
  }

  get timeRemaining() {
    return getTimeRemaining(this.args?.character, this._currentTime);
  }

  get activeAction() {
    const c = this.args?.character;
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

    return Math.min(100, Math.max(0, ((now - startT) / total) * 100));
  }

  get isGrowing() {
    return this.targetSizeCm > this.calculatedSizeCm + 0.0001;
  }

  get recentActions() {
    return (this.args?.character?.actions || []).slice(0, 5);
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
  async adminEdit() {
    const AdminEditModal = (await import("./modal/discourse-size-admin-edit")).default;
    this.modal.show(AdminEditModal, {
      model: {
        character: this.args?.character,
        onSave: (updatedChar) => {
          this.args?.onAction?.(updatedChar);
        }
      }
    });
  }
}
