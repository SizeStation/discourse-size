import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { UNITS, getBestUnit } from "../../lib/size-formatter";

export default class DiscourseSizeAdminEdit extends Component {
  @tracked originalCurrentSize = 0;
  @tracked isSaving = false;
  @tracked sizeUnit = "cm";
  @tracked displaySize = 0;

  constructor() {
    super(...arguments);
    const char = this.args?.model?.character || {};
    this.currentSize = char.current_size;
    this.originalCurrentSize = char.current_size;
    const unit = getBestUnit(this.currentSize);
    this.sizeUnit = unit.id;
    this.displaySize = parseFloat(
      (this.currentSize / unit.factor).toPrecision(5)
    );
  }

  get units() {
    return UNITS;
  }

  @action
  onUnitChange(unitId) {
    this.sizeUnit = unitId;
  }

  @action
  async save() {
    this.isSaving = true;

    const data = {};

    const unit = UNITS.find((u) => u.id === this.sizeUnit) || { factor: 1 };
    const currentSizeInCm = parseFloat(this.displaySize) * unit.factor;

    if (
      Math.abs(currentSizeInCm - parseFloat(this.originalCurrentSize)) > 0.0001
    ) {
      data.current_size = currentSizeInCm;
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
