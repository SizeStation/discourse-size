import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

export default class DiscourseSizeEditCharacter extends Component {
  @tracked name = "";
  @tracked picture = "";
  @tracked infoPost = "";
  @tracked baseSize = 170.0;
  @tracked measurementSystem = "imperial";
  @tracked allowGrowth = true;
  @tracked allowShrink = true;
  @tracked isSaving = false;
  @tracked infoPostId = null;

  @service currentUser;

  constructor() {
    super(...arguments);
    const char = this.args.model?.character || {};
    this.name = char.name || "";
    this.picture = char.picture || "";
    this.infoPost = char.info_post || "";
    this.baseSize = char.base_size || 170.0;
    this.measurementSystem = char.measurement_system || "imperial";
    this.allowGrowth = char.allow_growth !== false;
    this.allowShrink = char.allow_shrink !== false;
  }

  get resetButtonLabel() {
    return `Reset size to baseline of ${this.baseSize}cm`;
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
      formData.append("type", "avatar"); // Using avatar type for simple uploads

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


  get modalTitle() {
    return this.args.model?.isNew ? "Create Character" : "Edit Character";
  }

  @action
  async save() {
    this.isSaving = true;
    
    const data = {
      name: this.name,
      picture: this.picture,
      info_post: this.infoPost,
      base_size: this.baseSize,
      measurement_system: this.measurementSystem,
      allow_growth: this.allowGrowth,
      allow_shrink: this.allowShrink
    };

    try {
      let result;
      if (this.args.model?.isNew) {
        result = await ajax("/size/characters", { type: "POST", data });
      } else {
        result = await ajax(`/size/characters/${this.args.model?.character?.id}`, {
          type: "PUT",
          data,
        });
      }
      this.args.model?.onSave?.(result.character);
      this.args.closeModal?.();
    } catch (e) {
      alert(
        e.jqXHR?.responseJSON?.errors?.join(", ") || "Error saving character"
      );
    } finally {
      this.isSaving = false;
    }
  }

  get refundAmount() {
    const char = this.args.model?.character;
    if (!char) return 0;
    
    const targetOffset = char.target_offset || 0;
    return Math.floor(Math.abs(targetOffset) / 2);
  }

  @action
  async resetSize() {
    const refund = this.refundAmount;
    if (
      confirm(
        `Are you sure? This is not reversible. You will regain ${refund} points (50% of the points spent on growth).`
      )
    ) {
      try {
        const result = await ajax(
          `/size/characters/${this.args.model?.character?.id}/reset`,
          { type: "POST" }
        );
        this.args.model?.onSave?.(result.character);
        this.args.closeModal?.();
      } catch (e) {
        alert("Error resetting size");
      }
    }
  }

  @action
  onKeyDown(e) {
    if (e.key === "Enter") {
      // Prevent default form submission on enter
      e.preventDefault();
      return false;
    }
  }
}
