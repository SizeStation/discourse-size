import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

export default class DiscourseSizeAdminPoints extends Component {
  @tracked points = 0;
  @tracked isSaving = false;

  constructor() {
    super(...arguments);
    this.points = this.args?.model?.points || 0;
  }

  @action
  async save() {
    this.isSaving = true;

    try {
      await ajax(`/size/admin/users/${this.args?.model?.user?.id}/points`, {
        type: "PUT",
        data: { points: this.points },
      });
      this.args?.model?.onSave?.(this.points);
      this.args?.closeModal?.();
    } catch (e) {
      alert(e.jqXHR?.responseJSON?.error || "Error saving points");
    } finally {
      this.isSaving = false;
    }
  }
}
