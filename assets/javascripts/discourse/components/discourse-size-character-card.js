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
  @tracked boostAmountInput = 1;

  _timer = null;

  constructor() {
    super(...arguments);
    this._timer = setInterval(() => {
      if (
        this.args.character.target_offset !== this.args.character.current_offset
      ) {
        this._currentTime = new Date();
      }
    }, 100); // 10 fps
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this._timer) clearInterval(this._timer);
  }

  get calculatedSizeCm() {
    const c = this.args.character;
    if (!c.offset_updated_at || c.target_offset === c.current_offset) {
      return c.current_size;
    }

    const ratePercentPerDay =
      (c.growth_rate_override ||
        this.siteSettings.discourse_size_default_max_growth_rate) +
      (parseFloat(c.growth_rate_bought) || 0);
    if (ratePercentPerDay <= 0) return c.base_size + c.target_offset;

    const offsetDate = new Date(c.offset_updated_at);
    const daysElapsed =
      (this._currentTime.getTime() - offsetDate.getTime()) / 1000 / 86400.0;

    if (daysElapsed < 0) return c.current_size;

    const currentSize = c.base_size + c.current_offset;
    const targetSize = c.base_size + c.target_offset;
    const multiplier = Math.pow(1.0 + ratePercentPerDay / 100.0, daysElapsed);

    let newSize;
    if (c.target_offset > c.current_offset) {
      newSize = currentSize * multiplier;
      if (newSize > targetSize) newSize = targetSize;
    } else {
      newSize = currentSize / multiplier;
      if (newSize < targetSize) newSize = targetSize;
    }

    return newSize;
  }

  get formattedSize() {
    return formatSize(
      this.calculatedSizeCm,
      this.args.character.measurement_system
    );
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

  get pointsCost() {
    return Math.ceil(Math.abs(parseFloat(this.amountInput) || 0));
  }

  get projectedSpeedBoost() {
    const points = parseFloat(this.boostAmountInput) || 0;
    const ratePerPoint =
      this.siteSettings.discourse_size_speed_percentage_per_point || 0.1;
    return (points * ratePerPoint).toFixed(2);
  }

  get sizeChangeCm() {
    return Math.abs(parseFloat(this.amountInput) || 0);
  }

  get formattedSizeChange() {
    const val = parseFloat(this.amountInput) || 0;
    return formatSize(Math.abs(val), this.args.character.measurement_system);
  }

  get projectedGrowSize() {
    if (!this.args) return "";
    const points = parseFloat(this.amountInput) || 0;
    const base = parseFloat(this.args.character?.base_size || 0);
    const offset = parseFloat(this.args.character?.target_offset || 0);
    const currentTarget = base + offset;

    const rate =
      (this.siteSettings.discourse_size_percentage_per_point || 0.1) / 100.0;

    const target = currentTarget * Math.pow(1.0 + rate, points);
    return formatSize(target, this.args.character?.measurement_system);
  }

  get projectedShrinkSize() {
    if (!this.args?.character) return "";

    const points = parseFloat(this.amountInput) || 0;
    const base = parseFloat(this.args.character.base_size) || 170.0;
    const offset = parseFloat(this.args.character.target_offset) || 0.0;
    const currentTargetTotal = base + offset;

    const rate =
      (this.siteSettings.discourse_size_percentage_per_point || 0.1) / 100.0;

    const resultSizeCm = currentTargetTotal * Math.pow(1.0 - rate, points);

    return formatSize(resultSizeCm, this.args.character.measurement_system);
  }

  get pointsCost() {
    return Math.ceil(parseFloat(this.amountInput) || 0);
  }

  get pointsLeft() {
    const currentPoints = parseInt(this.args.userPoints, 10) || 0;
    return currentPoints - this.pointsCost;
  }

  get targetSizeCm() {
    return this.args.character.base_size + this.args.character.target_offset;
  }

  get formattedTargetSize() {
    return formatSize(
      this.targetSizeCm,
      this.args.character.measurement_system
    );
  }

  get isAnimating() {
    return (
      this.args.character.target_offset !== this.args.character.current_offset
    );
  }

  get formattedGrowthRate() {
    const c = this.args.character;
    const ratePercent =
      (c.growth_rate_override ||
        this.siteSettings.discourse_size_default_max_growth_rate) +
      (parseFloat(c.growth_rate_bought) || 0);
    return `${ratePercent.toFixed(2)}% / day`;
  }

  get timeRemaining() {
    const c = this.args.character;
    const currentSize = this.calculatedSizeCm;
    const targetSize = c.base_size + c.target_offset;

    // Prevent issues with floating point precision or zero sizes
    if (
      Math.abs(targetSize - currentSize) < 0.01 ||
      currentSize <= 0 ||
      targetSize <= 0
    )
      return null;

    const ratePercentPerDay =
      (c.growth_rate_override ||
        this.siteSettings.discourse_size_default_max_growth_rate) +
      (parseFloat(c.growth_rate_bought) || 0);
    if (ratePercentPerDay <= 0) return null;

    const multiplier = 1.0 + ratePercentPerDay / 100.0;
    const ratio = Math.max(targetSize / currentSize, currentSize / targetSize);

    // Calculate days required to reach the target ratio
    const daysRemaining = Math.log(ratio) / Math.log(multiplier);
    const seconds = daysRemaining * 86400;

    if (seconds < 60) return `${Math.ceil(seconds)}s`;
    if (seconds < 3600) return `${Math.ceil(seconds / 60)}m`;
    if (seconds < 86400) return `${Math.ceil(seconds / 3600)}h`;
    return `${(seconds / 86400).toFixed(1)}d`;
  }

  get progressPercent() {
    const c = this.args.character;
    const startOffset = parseFloat(c.current_offset);
    const targetOffset = parseFloat(c.target_offset);
    const currentOffset = this.calculatedSizeCm - parseFloat(c.base_size);

    if (Math.abs(targetOffset - startOffset) < 0.001) {
      return 100;
    }

    const progress =
      (currentOffset - startOffset) / (targetOffset - startOffset);
    return Math.min(100, Math.max(0, Math.round(progress * 100)));
  }

  get canEdit() {
    return this.args.isCurrentUser || this.currentUser?.admin;
  }

  get canGrow() {
    return this.args.character.allow_growth || this.args.isCurrentUser;
  }

  get canShrink() {
    return this.args.character.allow_shrink || this.args.isCurrentUser;
  }

  @action
  setAmount(event) {
    this.amountInput = event.target.value;
  }

  @action
  setBoostAmount(e) {
    this.boostAmountInput = e.target.value;
  }

  @action
  async boostSpeed() {
    try {
      const result = await ajax(
        `/size/characters/${this.args.character.id}/boost_speed`,
        {
          type: "POST",
          data: { amount: this.boostAmountInput },
        }
      );
      if (result.points !== undefined) {
        this.currentUser.set("discourse_size_points", result.points);
      }
      this.args.onAction();
    } catch (e) {
      alert(e.jqXHR?.responseJSON?.error || "Error boosting speed");
    }
  }

  @action
  showGrowthGraph() {
    this.modal.show(DiscourseSizeGrowthGraph, {
      model: {
        character: this.args.character,
      },
    });
  }

  @action
  async grow() {
    try {
      const result = await ajax(
        `/size/characters/${this.args.character.id}/grow`,
        {
          type: "POST",
          data: { amount: this.amountInput },
        }
      );
      if (result.points !== undefined) {
        this.currentUser.set("discourse_size_points", result.points);
      }
      this.args.onAction();
    } catch (e) {
      alert(e.jqXHR?.responseJSON?.error || "Error growing character");
    }
  }

  @action
  async shrink() {
    try {
      const result = await ajax(
        `/size/characters/${this.args.character.id}/shrink`,
        {
          type: "POST",
          data: { amount: this.amountInput },
        }
      );
      if (result.points !== undefined) {
        this.currentUser.set("discourse_size_points", result.points);
      }
      this.args.onAction();
    } catch (e) {
      alert(e.jqXHR?.responseJSON?.error || "Error shrinking character");
    }
  }

  @action
  async resetSize() {
    if (confirm("Reset size? You will regain 50% of the points spent.")) {
      try {
        const result = await ajax(
          `/size/characters/${this.args.character.id}/reset`,
          { type: "POST" }
        );
        if (result.points !== undefined) {
          this.currentUser.set("discourse_size_points", result.points);
        }
        this.args.onAction();
      } catch (e) {
        alert("Error resetting size");
      }
    }
  }

  @action
  async setMain() {
    try {
      await ajax(`/size/characters/${this.args.character.id}/set_main`, {
        type: "POST",
      });
      this.args.onAction();
    } catch (e) {
      alert("Error setting main character");
    }
  }

  @action
  adminEdit() {
    this.modal.show(DiscourseSizeAdminEdit, {
      model: {
        character: this.args.character,
        onSave: () => this.args.onAction(),
      },
    });
  }
}
