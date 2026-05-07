import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { UNITS, getBestUnit } from "../../lib/size-formatter";

export default class DiscourseSizeEditCharacter extends Component {
  @tracked name = "";
  @tracked picture = "";
  @tracked infoPost = "";
  @tracked gender = "";
  @tracked pronouns = "";
  @tracked age = "";
  @tracked species = "";
  @tracked description = "";
  @tracked baseSize = 170.0;
  @tracked showComparison = true;
  @tracked isSaving = false;
  @tracked infoPostId = null;
  @tracked sizeError = null;
  @tracked isMain = false;
  @tracked characterType = "game";
  @tracked sizeUnit = "cm";
  @tracked displaySize = 170.0;
  @tracked blockedItemKeys = [];
  @tracked blockedUserIds = [];
  @tracked availableItems = [];
  @tracked blockedUsers = [];
  @tracked blockUsername = "";

  @service currentUser;
  @service siteSettings;

  constructor() {
    super(...arguments);
    const char = this.args?.model?.character || {};
    this.name = char.name || "";
    this.picture = char.picture || "";
    this.infoPost = char.info_post || "";
    this.gender = char.gender || "";
    this.pronouns = char.pronouns || "";
    this.age = char.age || "";
    this.species = char.species || "";
    this.description = char.description || "";
    this.baseSize = char.base_size || 170.0;
    this.isMain = char.is_main || false;
    this.characterType = char.character_type || "game";
    this.showComparison = char.show_comparison !== false;
    this.blockedItemKeys = char.blocked_item_keys || [];
    this.blockedUserIds = (char.blocked_user_ids || []).map((id) =>
      parseInt(id, 10)
    );
    this.blockedUsers = char.blocked_users || [];

    if (this.characterType === "game") {
      this.fetchAvailableItems();
    }

    const unit = getBestUnit(this.baseSize);
    this.sizeUnit = unit.id;
    this.displaySize = parseFloat((this.baseSize / unit.factor).toPrecision(5));

    this._initialDisplaySize = this.displaySize;
    this._initialSizeUnit = this.sizeUnit;
  }

  get isDirty() {
    const char = this.args?.model?.character || {};
    const initialShowComparison = char.show_comparison !== false;

    return (
      this.name !== (char.name || "") ||
      this.picture !== (char.picture || "") ||
      this.infoPost !== (char.info_post || "") ||
      this.gender !== (char.gender || "") ||
      this.pronouns !== (char.pronouns || "") ||
      this.age !== (char.age || "") ||
      this.species !== (char.species || "") ||
      this.species !== (char.species || "") ||
      this.description !== (char.description || "") ||
      JSON.stringify(this.blockedItemKeys) !==
        JSON.stringify(char.blocked_item_keys || []) ||
      JSON.stringify(this.blockedUserIds) !==
        JSON.stringify(char.blocked_user_ids || []) ||
      this.showComparison !== initialShowComparison ||
      this.isMain !== (char.is_main || false) ||
      this.characterType !== (char.character_type || "game") ||
      parseFloat(this.displaySize) !== parseFloat(this._initialDisplaySize) ||
      this.sizeUnit !== this._initialSizeUnit
    );
  }

  @action
  close() {
    if (this.isDirty) {
      if (
        !confirm("You have unsaved changes. Are you sure you want to exit?")
      ) {
        return;
      }
    }
    this.args.closeModal();
  }

  get units() {
    return UNITS;
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
    return this.args?.model?.isNew ? "Create Character" : "Edit Character";
  }

  _checkSize(val) {
    if (isNaN(val)) {
      this.sizeError = "Please enter a valid number.";
      return;
    }

    if (this.characterType === "game") {
      if (val < this.min) {
        this.sizeError = `Minimum allowed size is ${this.min}cm.`;
      } else if (val > this.max) {
        this.sizeError = `Maximum allowed size is ${this.max}cm.`;
      } else {
        this.sizeError = null;
      }
    } else {
      // Freeform: allow any positive number
      if (val <= 0) {
        this.sizeError = "Size must be greater than 0.";
      } else {
        this.sizeError = null;
      }
    }
  }

  @action
  setCharType(type) {
    this.characterType = type;
  }

  @action
  onBaseSizeInput(event) {
    const val = parseFloat(event.target.value);
    this.displaySize = isNaN(val) ? event.target.value : val;
    this._checkSize(this.baseSizeInCm);
  }

  @action
  onUnitChange(unitId) {
    this.sizeUnit = unitId;
    this._checkSize(this.baseSizeInCm);
  }

  get baseSizeInCm() {
    const unit = UNITS.find((u) => u.id === this.sizeUnit) || { factor: 1 };
    return parseFloat(this.displaySize) * unit.factor;
  }

  @action
  onBaseSizeBlur(event) {
    let val = parseFloat(event.target.value);
    const unit = UNITS.find((u) => u.id === this.sizeUnit) || { factor: 1 };
    let valCm = val * unit.factor;

    if (this.characterType === "game") {
      if (isNaN(valCm) || valCm < this.min) {
        this.displaySize = parseFloat((this.min / unit.factor).toPrecision(5));
        this.sizeError = `Clamped to minimum: ${this.min}cm.`;
      } else if (valCm > this.max) {
        this.displaySize = parseFloat((this.max / unit.factor).toPrecision(5));
        this.sizeError = `Clamped to maximum: ${this.max}cm.`;
      } else {
        this.displaySize = val;
        this.sizeError = null;
      }
    } else {
      if (isNaN(valCm) || valCm <= 0) {
        this.displaySize = parseFloat((1.0 / unit.factor).toPrecision(5));
        this.sizeError = "Size must be greater than 0.";
      } else {
        this.displaySize = val;
        this.sizeError = null;
      }
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
    let valCm = this.baseSizeInCm;
    if (this.characterType === "game") {
      if (isNaN(valCm) || valCm < this.min) {
        valCm = this.min;
      } else if (valCm > this.max) {
        valCm = this.max;
      }
    } else {
      if (isNaN(valCm) || valCm <= 0) {
        valCm = 1.0;
      }
    }
    this.sizeError = null;

    this.isSaving = true;

    const data = {
      name: this.name,
      picture: this.picture,
      info_post: this.infoPost,
      base_size: valCm,
      base_size: valCm,
      blocked_item_keys: this.blockedItemKeys,
      blocked_user_ids: this.blockedUserIds,
      character_type: this.characterType,
      gender: this.gender,
      pronouns: this.pronouns,
      age: this.age,
      species: this.species,
      description: this.description,
      show_comparison: this.showComparison,
      is_main: this.isMain,
    };

    try {
      let result;
      if (this.args?.model?.isNew) {
        result = await ajax("/size/characters", { type: "POST", data });
      } else {
        result = await ajax(
          `/size/characters/${this.args?.model?.character?.id}`,
          {
            type: "PUT",
            data,
          }
        );
      }
      this.args?.model?.onSave?.(result.character);
      this.args?.closeModal?.();
    } catch (e) {
      alert(
        e.jqXHR?.responseJSON?.errors?.join(", ") || "Error saving character"
      );
    } finally {
      this.isSaving = false;
    }
  }

  get refundAmount() {
    const char = this.args?.model?.character;
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
      !this.args?.model?.isNew &&
      this.args?.model?.character?.id &&
      !this.isMain
    );
  }

  @action
  async deleteCharacter() {
    const confirmed = confirm(
      "Are you sure you want to delete this character? This cannot be undone, and you will NOT get any points back."
    );
    if (!confirmed) return;

    try {
      await ajax(`/size/characters/${this.args?.model?.character?.id}`, {
        type: "DELETE",
      });
      this.args?.model?.onDelete?.();
      this.args?.closeModal?.();
    } catch (e) {
      alert("Error deleting character");
    }
  }

  async fetchAvailableItems() {
    try {
      const result = await ajax("/size/shop");
      this.availableItems = result.items || [];
    } catch (e) {
      console.error("Error fetching shop items", e);
    }
  }

  get blockingMode() {
    if (this.blockedItemKeys.includes("__all__")) return "all";
    if (this.blockedItemKeys.includes("__all_growing__")) return "growing";
    if (this.blockedItemKeys.includes("__all_shrinking__")) return "shrinking";
    if (this.blockedItemKeys.length === 0) return "none";
    return "custom";
  }

  @action
  isItemBlocked(key) {
    if (this.blockedItemKeys.includes("__all__")) return true;
    const item = this.availableItems.find((i) => i.key === key);
    if (item) {
      if (
        item.effect === "grow" &&
        this.blockedItemKeys.includes("__all_growing__")
      ) {
        return true;
      }
      if (
        item.effect === "shrink" &&
        this.blockedItemKeys.includes("__all_shrinking__")
      ) {
        return true;
      }
    }
    return this.blockedItemKeys.includes(key);
  }

  @action
  toggleItemBlock(key) {
    let newKeys = [...this.blockedItemKeys];

    // If we were in a special mode, "explode" it to individual keys first
    if (newKeys.includes("__all__")) {
      newKeys = this.availableItems.map((i) => i.key);
    } else if (newKeys.includes("__all_growing__")) {
      newKeys = this.availableItems
        .filter((i) => i.effect === "grow")
        .map((i) => i.key);
    } else if (newKeys.includes("__all_shrinking__")) {
      newKeys = this.availableItems
        .filter((i) => i.effect === "shrink")
        .map((i) => i.key);
    }

    if (newKeys.includes(key)) {
      newKeys = newKeys.filter((k) => k !== key);
    } else {
      newKeys.push(key);
    }

    this.blockedItemKeys = newKeys;
  }

  @action
  blockAll() {
    this.blockedItemKeys = ["__all__"];
  }

  @action
  blockNone() {
    this.blockedItemKeys = [];
  }

  @action
  blockAllGrowing() {
    this.blockedItemKeys = ["__all_growing__"];
  }

  @action
  blockAllShrinking() {
    this.blockedItemKeys = ["__all_shrinking__"];
  }

  @action
  unblockUser(userId) {
    const idToMatch = parseInt(userId, 10);
    this.blockedUserIds = this.blockedUserIds.filter(
      (id) => parseInt(id, 10) !== idToMatch
    );
    this.blockedUsers = this.blockedUsers.filter(
      (u) => parseInt(u.id, 10) !== idToMatch
    );
  }

  @action
  onUserSelected(users) {
    if (!users || users.length === 0) return;

    // EmailGroupUserChooser gives us a list of usernames
    // But we need to resolve them to objects with id and username
    // Since it's a search field, we'll fetch the user data
    users.forEach(async (username) => {
      try {
        const user = await ajax(`/u/${username}.json`);
        if (user && user.user) {
          const userId = parseInt(user.user.id, 10);
          if (!this.blockedUserIds.includes(userId)) {
            this.blockedUserIds = [...this.blockedUserIds, userId];
            this.blockedUsers = [
              ...this.blockedUsers,
              {
                id: userId,
                username: user.user.username,
                avatar_template: user.user.avatar_template,
              },
            ];
          }
        }
      } catch (e) {
        console.error("Could not find user:", username);
      }
    });
  }

  get growingItems() {
    return this.availableItems.filter((i) => i.effect === "grow");
  }

  get shrinkingItems() {
    return this.availableItems.filter((i) => i.effect === "shrink");
  }

  get otherItems() {
    return this.availableItems.filter(
      (i) => i.effect !== "grow" && i.effect !== "shrink"
    );
  }
}
