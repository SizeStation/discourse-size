import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { formatSize } from "../lib/size-formatter";

export default class DiscourseSizeCharacterActions extends Component {
  @service siteSettings;
  @service currentUser;

  @tracked amountInput = 10;
  @tracked boostAmountInput = 10;
  @tracked freeformSizeInput = "";

  constructor() {
    super(...arguments);
    if (this.args.character.character_type === "freeform") {
      this.freeformSizeInput = (this.args.character.current_size || this.args.character.base_size).toString();
    }
  }

  get isGame() {
    return this.args.character.character_type === "game";
  }

  get isFreeform() {
    return this.args.character.character_type === "freeform";
  }

  get canEdit() {
    return this.args.isCurrentUser || this.currentUser?.admin;
  }

  get canGrow() {
    return this.args.character.allow_growth || this.canEdit;
  }

  get canShrink() {
    return this.args.character.allow_shrink || this.canEdit;
  }

  @action
  setAmount(event) {
    this.amountInput = event.target.value;
  }

  @action
  setBoostAmount(event) {
    this.boostAmountInput = event.target.value;
  }

  @action
  setFreeformSize(event) {
    this.freeformSizeInput = event.target.value;
  }

  @action
  async grow() {
    const amount = parseFloat(this.amountInput);
    if (isNaN(amount) || amount <= 0) return;

    try {
      const result = await ajax(`/size/characters/${this.args.character.id}/grow`, {
        type: "POST",
        data: { amount },
      });
      this.args.onAction?.(result);
    } catch (e) {
      alert(e.jqXHR?.responseJSON?.error || "Error growing character");
    }
  }

  @action
  async shrink() {
    const amount = parseFloat(this.amountInput);
    if (isNaN(amount) || amount <= 0) return;

    try {
      const result = await ajax(`/size/characters/${this.args.character.id}/shrink`, {
        type: "POST",
        data: { amount },
      });
      this.args.onAction?.(result);
    } catch (e) {
      alert(e.jqXHR?.responseJSON?.error || "Error shrinking character");
    }
  }

  @action
  async setSize() {
    const size = parseFloat(this.freeformSizeInput);
    if (isNaN(size)) return;

    try {
      const result = await ajax(`/size/characters/${this.args.character.id}/set_size`, {
        type: "POST",
        data: { size },
      });
      this.args.onAction?.(result);
    } catch (e) {
      alert(e.jqXHR?.responseJSON?.error || "Error setting size");
    }
  }

  @action
  async boostSpeed() {
    const amount = parseFloat(this.boostAmountInput);
    if (isNaN(amount) || amount <= 0) return;

    try {
      const result = await ajax(`/size/characters/${this.args.character.id}/boost_speed`, {
        type: "POST",
        data: { amount },
      });
      this.args.onAction?.(result);
    } catch (e) {
      alert(e.jqXHR?.responseJSON?.error || "Error boosting speed");
    }
  }

  get projectedGrowSize() {
    const amount = parseFloat(this.amountInput) || 0;
    const rate =
      (this.siteSettings.discourse_size_percentage_per_point || 1) / 100.0;
    const currentTargetTotal =
      this.args.character.base_size + this.args.character.target_offset;
    const newTargetTotal = currentTargetTotal * Math.pow(1.0 + rate, amount);
    return formatSize(newTargetTotal, this.args.character.measurement_system);
  }

  get projectedShrinkSize() {
    const amount = parseFloat(this.amountInput) || 0;
    const rate =
      (this.siteSettings.discourse_size_percentage_per_point || 1) / 100.0;
    const currentTargetTotal =
      this.args.character.base_size + this.args.character.target_offset;
    const newTargetTotal = currentTargetTotal * Math.pow(1.0 - rate, amount);
    return formatSize(newTargetTotal, this.args.character.measurement_system);
  }

  get projectedSpeedBoost() {
    const amount = parseFloat(this.boostAmountInput) || 0;
    const bonus =
      amount *
      (this.siteSettings.discourse_size_speed_percentage_per_point || 0.1);
    return bonus.toFixed(2);
  }
}
