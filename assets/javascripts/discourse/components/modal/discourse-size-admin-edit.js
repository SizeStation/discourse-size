import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

export default class DiscourseSizeAdminEdit extends Component {
  @tracked baseSize = this.args.model.character.base_size;
  @tracked currentSize = this.args.model.character.current_size;
  @tracked growthRateOverride = this.args.model.character.growth_rate_override || "";
  @tracked isSaving = false;

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
      await ajax(`/size/admin/characters/${this.args.model.character.id}`, { type: "PUT", data });
      this.args.model.onSave();
      this.args.closeModal();
    } catch (e) {
      alert(e.jqXHR?.responseJSON?.errors?.join(", ") || "Error saving character as admin");
    } finally {
      this.isSaving = false;
    }
  }
}
