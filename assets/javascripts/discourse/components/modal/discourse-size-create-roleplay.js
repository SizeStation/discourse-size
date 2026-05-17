import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";

export default class DiscourseSizeCreateRoleplay extends Component {
  @tracked name = this.args.model.roleplay?.name || "";
  @tracked description = this.args.model.roleplay?.description || "";
  @tracked picture = this.args.model.roleplay?.picture || "";
  @tracked isPublic = this.args.model.roleplay ? this.args.model.roleplay.is_public : true;
  @tracked saving = false;

  get isEditing() {
    return !!this.args.model.roleplay;
  }

  @action
  async uploadImage() {
    const fileInput = document.createElement("input");
    fileInput.type = "file";
    fileInput.accept = "image/*";
    fileInput.onchange = async (e) => {
      const file = e.target.files[0];
      if (!file) return;

      const formData = new FormData();
      formData.append("file", file);
      formData.append("type", "composer");

      try {
        const result = await ajax("/uploads.json", {
          type: "POST",
          data: formData,
          cache: false,
          contentType: false,
          processData: false,
        });
        this.picture = result.url;
      } catch (err) {
        alert("Error uploading image");
      }
    };
    fileInput.click();
  }

  @action
  async save() {
    if (!this.name) return;
    this.saving = true;

    const data = {
      name: this.name,
      description: this.description,
      picture: this.picture,
      is_public: this.isPublic,
    };

    try {
      let result;
      if (this.isEditing) {
        result = await ajax(`/size/roleplays/${this.args.model.roleplay.id}`, {
          type: "PUT",
          data,
        });
      } else {
        result = await ajax("/size/roleplays", {
          type: "POST",
          data,
        });
      }
      this.args.model.onSave?.(result.roleplay);
      this.args.model.onCreate?.(result.roleplay);
      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.saving = false;
    }
  }
}
