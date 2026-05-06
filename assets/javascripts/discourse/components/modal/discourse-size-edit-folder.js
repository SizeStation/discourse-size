import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

export default class DiscourseSizeEditFolder extends Component {
  @tracked name = this.args.model.folder?.name || "";
  @tracked hexColor = this.args.model.folder?.hex_color || "";
  @tracked isSaving = false;

  get title() {
    return this.args.model.isNew ? "Create Folder" : "Edit Folder";
  }

  @action
  clearColor() {
    this.hexColor = "";
  }

  @action
  handleKeyDown(event) {
    if (event.key === "Enter") {
      this.save();
    }
  }

  @action
  async save() {
    if (!this.name || this.name.trim() === "") {
      return;
    }

    this.isSaving = true;
    const data = {
      folder: {
        name: this.name.trim(),
        hex_color: this.hexColor,
      },
    };

    try {
      let result;
      if (this.args.model.isNew) {
        result = await ajax("/size/folders", { type: "POST", data });
      } else {
        result = await ajax(`/size/folders/${this.args.model.folder.id}`, {
          type: "PUT",
          data,
        });
      }
      this.args.model.onSave?.(result.folder);
      this.args.closeModal();
    } catch (e) {
      // Handle error
    } finally {
      this.isSaving = false;
    }
  }

  @action
  async deleteFolder() {
    if (
      confirm(
        "Are you sure you want to delete this folder? Characters in the folder will not be deleted; they will become unorganized."
      )
    ) {
      try {
        await ajax(`/size/folders/${this.args.model.folder.id}`, {
          type: "DELETE",
        });
        this.args.model.onSave?.();
        this.args.closeModal();
      } catch (e) {
        alert("Error deleting folder");
      }
    }
  }
}
