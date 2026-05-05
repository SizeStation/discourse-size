import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { UNITS, getBestUnit } from "../../lib/size-formatter";

export default class DiscourseSizeAdminEdit extends Component {
  @tracked baseSize = 0;
  @tracked currentSize = 0;
  @tracked growthRateOverride = "";
  @tracked originalBaseSize = 0;
  @tracked originalCurrentSize = 0;
  @tracked isSaving = false;
  @tracked sizeUnit = "cm";
  @tracked displaySize = 0;
  @tracked baseSizeUnit = "cm";
  @tracked displayBaseSize = 0;

  constructor() {
    super(...arguments);
    const char = this.args?.model?.character || {};
    this.baseSize = char.base_size;
    this.currentSize = char.current_size;
    this.originalBaseSize = char.base_size;
    this.originalCurrentSize = char.current_size;
    this.growthRateOverride = char.growth_rate_override || "";

    const unit = getBestUnit(this.currentSize);
    this.sizeUnit = unit.id;
    this.displaySize = parseFloat((this.currentSize / unit.factor).toPrecision(5));

    const bUnit = getBestUnit(this.baseSize);
    this.baseSizeUnit = bUnit.id;
    this.displayBaseSize = parseFloat((this.baseSize / bUnit.factor).toPrecision(5));
  }

  get units() {
    return UNITS;
  }

  @action
  onUnitChange(unitId) {
    this.sizeUnit = unitId;
  }

  @action
  onBaseSizeUnitChange(unitId) {
    this.baseSizeUnit = unitId;
  }

  @action
  async save() {
    this.isSaving = true;

    const data = {};

    const unit = UNITS.find((u) => u.id === this.sizeUnit) || { factor: 1 };
    const currentSizeInCm = parseFloat(this.displaySize) * unit.factor;

    const bUnit = UNITS.find((u) => u.id === this.baseSizeUnit) || { factor: 1 };
    const baseSizeInCm = parseFloat(this.displayBaseSize) * bUnit.factor;

    if (Math.abs(baseSizeInCm - parseFloat(this.originalBaseSize)) > 0.0001) {
      data.base_size = baseSizeInCm;
    }

    if (Math.abs(currentSizeInCm - parseFloat(this.originalCurrentSize)) > 0.0001) {
      data.current_size = currentSizeInCm;
    }

    if (this.growthRateOverride !== "") {
      data.growth_rate_override = this.growthRateOverride;
    } else {
      data.growth_rate_override = null;
    }

    try {
      await ajax(`/size/admin/characters/${this.args?.model?.character?.id}`, {
        type: "PUT",
        data,
      });
      this.args?.model?.onSave?.();
      this.args?.closeModal?.();
    } catch (e) {
      alert(
        e.jqXHR?.responseJSON?.errors?.join(", ") ||
          "Error saving character as admin"
      );
    } finally {
      this.isSaving = false;
    }
  }
}
