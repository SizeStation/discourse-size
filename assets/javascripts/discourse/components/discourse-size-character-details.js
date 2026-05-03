import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { formatSize, getComparison } from "../lib/size-formatter";

export default class DiscourseSizeCharacterDetails extends Component {
  @service siteSettings;

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

    const rateCmPerDay =
      c.growth_rate_override ||
      this.siteSettings.discourse_size_default_max_growth_rate;
    if (rateCmPerDay <= 0) return c.base_size + c.target_offset;

    const rateCmPerSec = rateCmPerDay / 86400.0;
    const offsetDate = new Date(c.offset_updated_at);
    const secondsElapsed =
      (this._currentTime.getTime() - offsetDate.getTime()) / 1000;

    if (secondsElapsed < 0) return c.current_size;

    const maxChange = rateCmPerSec * secondsElapsed;
    let newOffset;

    if (c.target_offset > c.current_offset) {
      newOffset = c.current_offset + maxChange;
      if (newOffset > c.target_offset) newOffset = c.target_offset;
    } else {
      newOffset = c.current_offset - maxChange;
      if (newOffset < c.target_offset) newOffset = c.target_offset;
    }

    return c.base_size + newOffset;
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
}
