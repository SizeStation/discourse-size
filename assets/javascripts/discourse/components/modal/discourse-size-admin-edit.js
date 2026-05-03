import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

export default class DiscourseSizeAdminEdit extends Component {
  @tracked baseSize = 0;
  @tracked currentSize = 0;
  @tracked growthRateOverride = "";
  @tracked isSaving = false;

  constructor() {
    super(...arguments);
    const char = this.args.model?.character || {};
    this.baseSize = char.base_size;
    this.currentSize = char.current_size;
    this.growthRateOverride = char.growth_rate_override || "";
  }

  @action
  async save() {
    this.isSaving = true;

    const data = {
      base_size: this.baseSize,
      current_size: this.currentSize,
    };

    if (this.growthRateOverride !== "") {
      data.growth_rate_override = this.growthRateOverride;
    } else {
      data.growth_rate_override = null;
    }

    try {
      await ajax(`/size/admin/characters/${this.args.model?.character?.id}`, {
        type: "PUT",
        data,
      });
      this.args.model?.onSave?.();
      this.args.closeModal?.();
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
