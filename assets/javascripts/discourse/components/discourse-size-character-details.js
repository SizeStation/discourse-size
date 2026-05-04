import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { formatSize, getComparison, getGrowthComparison } from "../lib/size-formatter";

const MAX_SIZE = 1e120;

export default class DiscourseSizeCharacterDetails extends Component {
  @service siteSettings;
  @service currentUser;

  @tracked _currentTime = new Date();
  _timer = null;

  constructor() {
    super(...arguments);
    this._timer = setInterval(() => {
      if (
        this.args.character.target_offset !== this.args.character.current_offset
      ) {
        this._currentTime = new Date();
      }
    }, 100);
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
      if (newSize > MAX_SIZE) newSize = MAX_SIZE;
    } else {
      newSize = currentSize / multiplier;
      if (newSize < targetSize) newSize = targetSize;
    }

    return newSize;
  }

  get formattedGrowthRate() {
    const c = this.args.character;
    const ratePercent =
      (c.growth_rate_override ||
        this.siteSettings.discourse_size_default_max_growth_rate) +
      (parseFloat(c.growth_rate_bought) || 0);
    return `${ratePercent.toFixed(2)}% / day`;
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

  get canEdit() {
    return this.args.isCurrentUser || this.currentUser?.admin;
  }

  get showSpeed() {
    return this.args.character.character_type === "game";
  }

  get showActions() {
    if (!this.currentUser) return false;
    if (this.args.character.character_type === "freeform") return false;
    return true;
  }

  get timeRemaining() {
    const c = this.args.character;
    const currentSize = this.calculatedSizeCm;
    const targetSize = c.base_size + c.target_offset;

    if (
      Math.abs(targetSize - currentSize) < 0.01 ||
      currentSize <= 0 ||
      targetSize <= 0
    ) {
      return null;
    }

    const ratePercentPerDay =
      (c.growth_rate_override ||
        this.siteSettings.discourse_size_default_max_growth_rate) +
      (parseFloat(c.growth_rate_bought) || 0);
    if (ratePercentPerDay <= 0) {
      return null;
    }

    const multiplier = 1.0 + ratePercentPerDay / 100.0;
    const ratio = Math.max(targetSize / currentSize, currentSize / targetSize);

    const daysRemaining = Math.log(ratio) / Math.log(multiplier);
    const seconds = daysRemaining * 86400;

    if (seconds < 60) {
      return `${Math.ceil(seconds)}s`;
    }
    if (seconds < 3600) {
      const m = Math.floor(seconds / 60);
      const s = Math.floor(seconds % 60);
      return s > 0 ? `${m}m ${s}s` : `${m}m`;
    }
    if (seconds < 86400) {
      const h = Math.floor(seconds / 3600);
      const m = Math.floor((seconds % 3600) / 60);
      return m > 0 ? `${h}h ${m}m` : `${h}h`;
    }
    return `${(seconds / 86400).toFixed(1)}d`;
  }

  get targetSizeCm() {
    return (
      parseFloat(this.args.character.base_size) +
      parseFloat(this.args.character.target_offset)
    );
  }

  get formattedTargetSize() {
    return formatSize(
      this.targetSizeCm,
      this.args.character.measurement_system
    );
  }
}
