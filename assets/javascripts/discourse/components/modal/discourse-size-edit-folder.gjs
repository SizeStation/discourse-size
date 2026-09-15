import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
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

  <template>
    <DModal
      @title={{this.title}}
      @closeModal={{@closeModal}}
      class="discourse-size-edit-folder-modal"
    >
      <:body>
        <div class="control-group">
          <label>Folder Name</label>
          <Input
            @type="text"
            @value={{this.name}}
            autofocus="autofocus"
            class="folder-name-input"
            {{on "keydown" this.handleKeyDown}}
          />
        </div>

        <div class="control-group">
          <label>Folder Color</label>
          <div class="color-picker-wrapper">
            <Input
              @type="color"
              @value={{this.hexColor}}
              class="folder-color-input"
            />
            {{#if this.hexColor}}
              <span class="color-value">{{this.hexColor}}</span>
              <DButton
                @action={{this.clearColor}}
                class="btn-danger"
              >Clear</DButton>
            {{else}}
              <span class="color-value">(Default)</span>
            {{/if}}
          </div>
        </div>
      </:body>

      <:footer>
        <div class="modal-footer-actions">
          <div class="main-actions">
            <DButton
              @action={{this.save}}
              @label={{if
                @model.isNew
                "discourse_size.create"
                "discourse_size.save"
              }}
              @disabled={{this.isSaving}}
              class="btn-primary"
            />
            <DButton
              @action={{@closeModal}}
              @label="discourse_size.cancel"
              class="btn-default"
            />
          </div>

          {{#unless @model.isNew}}
            <DButton
              @action={{this.deleteFolder}}
              @label="discourse_size.delete_folder"
              class="btn-danger"
            />
          {{/unless}}
        </div>
      </:footer>
    </DModal>
  </template>
}
