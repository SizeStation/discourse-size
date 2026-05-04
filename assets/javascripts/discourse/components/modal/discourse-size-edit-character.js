import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

export default class DiscourseSizeEditCharacter extends Component {
  @tracked name = "";
  @tracked picture = "";
  @tracked infoPost = "";
  @tracked gender = "";
  @tracked pronouns = "";
  @tracked age = "";
  @tracked description = "";
  @tracked baseSize = 170.0;
  @tracked measurementSystem = "imperial";
  @tracked allowGrowth = true;
  @tracked allowShrink = true;
  @tracked showComparison = true;
  @tracked isSaving = false;
  @tracked infoPostId = null;
  @tracked sizeError = null;
  @tracked isMain = false;
  @tracked characterType = "game";

  @service currentUser;
  @service siteSettings;

  constructor() {
    super(...arguments);
    const char = this.args.model?.character || {};
    this.name = char.name || "";
    this.picture = char.picture || "";
    this.infoPost = char.info_post || "";
    this.gender = char.gender || "";
    this.pronouns = char.pronouns || "";
    this.age = char.age || "";
    this.description = char.description || "";
    this.baseSize = char.base_size || 170.0;
    this.measurementSystem = char.measurement_system || "imperial";
    this.allowShrink = char.allow_shrink !== false;
    this.isMain = char.is_main || false;
    this.characterType = char.character_type || "game";
    this.showComparison = char.show_comparison !== false;
  }

  get min() {
    return this.siteSettings.discourse_size_min_base_size;
  }

  get max() {
    return this.siteSettings.discourse_size_max_base_size;
  }

  get isInvalid() {
    return this.sizeError !== null && !this.sizeError.startsWith("Clamped");
  }

  get resetButtonLabel() {
    return `Reset size to baseline of ${this.baseSize}cm`;
  }

  get modalTitle() {
    return this.args.model?.isNew ? "Create Character" : "Edit Character";
  }

  _checkSize(val) {
    if (isNaN(val)) {
      this.sizeError = "Please enter a valid number.";
    } else if (val < this.min) {
      this.sizeError = `Minimum allowed size is ${this.min}cm.`;
    } else if (val > this.max) {
      this.sizeError = `Maximum allowed size is ${this.max}cm.`;
    } else {
      this.sizeError = null;
    }
  }

  @action
  setCharType(type) {
    this.characterType = type;
  }

  @action
  onBaseSizeInput(event) {
    const val = parseFloat(event.target.value);
    this.baseSize = isNaN(val) ? event.target.value : val;
    this._checkSize(val);
  }

  @action
  onBaseSizeBlur(event) {
    let val = parseFloat(event.target.value);

    if (isNaN(val) || val < this.min) {
      this.baseSize = this.min;
      this.sizeError = `Clamped to minimum: ${this.min}cm.`;
    } else if (val > this.max) {
      this.baseSize = this.max;
      this.sizeError = `Clamped to maximum: ${this.max}cm.`;
    } else {
      this.baseSize = val;
      this.sizeError = null;
    }
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
      formData.append("type", "avatar");

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
    // Final clamp before submitting
    const val = parseFloat(this.baseSize);
    if (isNaN(val) || val < this.min) {
      this.baseSize = this.min;
    } else if (val > this.max) {
      this.baseSize = this.max;
    }
    this.sizeError = null;

    this.isSaving = true;

    const data = {
      name: this.name,
      picture: this.picture,
      info_post: this.infoPost,
      base_size: this.baseSize,
      measurement_system: this.measurementSystem,
      allow_growth: this.allowGrowth,
      allow_shrink: this.allowShrink,
      character_type: this.characterType,
      gender: this.gender,
      pronouns: this.pronouns,
      age: this.age,
      description: this.description,
      show_comparison: this.showComparison,
      is_main: this.isMain,
    };

    try {
      let result;
      if (this.args.model?.isNew) {
        result = await ajax("/size/characters", { type: "POST", data });
      } else {
        result = await ajax(
          `/size/characters/${this.args.model?.character?.id}`,
          {
            type: "PUT",
            data,
          }
        );
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
    return char.character_type === "game"
      ? 0
      : Math.floor(Math.abs(targetOffset) / 2);
  }

  @action
  onKeyDown(e) {
    if (e.key === "Enter") {
      e.preventDefault();
      return false;
    }
  }

  get canSetMain() {
    return (
      !this.args.model?.isNew && this.args.model?.character?.id && !this.isMain
    );
  }

  @action
  async deleteCharacter() {
    const confirmed = confirm(
      "Are you sure you want to delete this character? This cannot be undone, and you will NOT get any points back."
    );
    if (!confirmed) return;

    try {
      await ajax(`/size/characters/${this.args.model?.character?.id}`, {
        type: "DELETE",
      });
      this.args.model?.onDelete?.();
      this.args.closeModal?.();
    } catch (e) {
      alert("Error deleting character");
    }
  }
}
