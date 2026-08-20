import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input, Textarea } from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class DiscourseSizeCreateRoleplay extends Component {
  @tracked name = this.args.model.roleplay?.name || "";
  @tracked description = this.args.model.roleplay?.description || "";
  @tracked picture = this.args.model.roleplay?.picture || "";
  @tracked
  isPublic = this.args.model.roleplay
    ? this.args.model.roleplay.is_public
    : true;
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
      if (!file) {
        return;
      }

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
    if (!this.name) {
      return;
    }
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

  <template>
    <DModal
      @title={{i18n "discourse_size.roleplays.modals.create.title"}}
      @closeModal={{@closeModal}}
      class="discourse-size-create-roleplay-modal"
    >
      <:body>
        <div class="roleplay-form">
          <div class="control-group">
            <label>{{i18n "discourse_size.fields.name"}}</label>
            <Input @type="text" @value={{this.name}} />
          </div>

          <div class="control-group">
            <label>{{i18n "discourse_size.fields.picture"}}</label>
            <div class="picture-upload-wrapper">
              {{#if this.picture}}
                <img
                  src={{this.picture}}
                  alt="Preview"
                  class="upload-preview"
                />
              {{/if}}
              <div class="upload-controls">
                <DButton
                  @action={{this.uploadImage}}
                  @label="discourse_size.upload_picture"
                  @icon="upload"
                  class="btn-default"
                />
              </div>
            </div>
          </div>

          <div class="control-group">
            <label>{{i18n "discourse_size.description"}}</label>
            <Textarea @value={{this.description}} />
          </div>

          <div class="control-group checkbox-group">
            <label>
              <Input @type="checkbox" @checked={{this.isPublic}} />
              {{i18n "discourse_size.roleplays.is_public"}}
            </label>
          </div>
        </div>
      </:body>

      <:footer>
        <DButton
          @action={{this.save}}
          @label="discourse_size.roleplays.modals.create.create_btn"
          @icon="plus"
          class="btn-primary"
          @disabled={{this.saving}}
        />
      </:footer>
    </DModal>
  </template>
}
