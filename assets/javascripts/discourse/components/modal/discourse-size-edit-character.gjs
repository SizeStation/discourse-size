import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input, Textarea } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { eq, notEq, or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";
import { formatSize, getBestUnit, UNITS } from "../../lib/size-formatter";
import DiscourseSizeTriggerHelp from "./discourse-size-trigger-help";

export default class DiscourseSizeEditCharacter extends Component {
  @service currentUser;

  @service siteSettings;

  @service modal;

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
  @tracked isClampedNotice = false;
  @tracked blockedItemKeys = [];
  @tracked blockedUserIds = [];
  @tracked availableItems = [];
  @tracked blockedUsers = [];
  @tracked blockUsername = "";
  @tracked properties = [];
  @tracked triggers = [];

  constructor() {
    super(...arguments);
    const char = this.args?.model?.character || {};
    const member = this.args?.model?.member;
    this.member = member;
    const ov = member?.override_data || {};

    this.name = ov.name ?? char.name ?? "";
    this.picture = ov.picture ?? char.picture ?? "";
    this.infoPost = ov.info_post ?? char.info_post ?? "";
    this.gender = ov.gender ?? char.gender ?? "";
    this.pronouns = ov.pronouns ?? char.pronouns ?? "";
    this.age = ov.age ?? char.age ?? "";
    this.species = ov.species ?? char.species ?? "";
    this.description = ov.description ?? char.description ?? "";
    this.baseSize =
      ov.base_size != null ? parseFloat(ov.base_size) : char.base_size || 170.0;
    this.isMain = ov.is_main ?? (char.is_main || false);
    this.characterType = char.character_type || "game";
    this.showComparison = ov.show_comparison ?? char.show_comparison !== false;
    this.blockedItemKeys = Array.isArray(ov.blocked_item_keys)
      ? ov.blocked_item_keys
      : char.blocked_item_keys || [];
    this.blockedUserIds = (
      (ov.blocked_user_ids ?? char.blocked_user_ids) ||
      []
    ).map((id) => parseInt(id, 10));
    this.blockedUsers = char.blocked_users || [];
    this.properties = (
      Array.isArray(ov.properties) ? ov.properties : char.properties || []
    ).map((p) => ({
      ...p,
      _valueUnit: p.property_type === "size" ? "cm" : undefined,
    }));
    this.triggers = (
      Array.isArray(ov.triggers) ? ov.triggers : char.triggers || []
    ).map((t) => ({ ...t }));

    if (this.characterType === "game") {
      this.fetchAvailableItems();
    }

    const initialSize =
      this.characterType === "normal" && char.current_size != null
        ? char.current_size
        : this.baseSize;
    const preferredSystem =
      this.currentUser?.discourse_size_settings?.measurement_system ||
      char.measurement_system ||
      "imperial";
    const unit = getBestUnit(initialSize, preferredSystem);
    this.sizeUnit = unit.id;
    this.displaySize = parseFloat((initialSize / unit.factor).toPrecision(5));

    this._initialDisplaySize = this.displaySize;
    this._initialSizeUnit = this.sizeUnit;
  }

  get preferredSystem() {
    return (
      this.currentUser?.discourse_size_settings?.measurement_system ||
      this.args?.model?.character?.measurement_system ||
      "imperial"
    );
  }

  get isRoleplayEdit() {
    return !!this.member;
  }

  _triggersEqual(a, b) {
    if (a.length !== b.length) {
      return false;
    }
    return a.every((t, i) => {
      const u = b[i];
      return (
        t.name === u.name &&
        t.js_code === u.js_code &&
        t._destroy === u._destroy
      );
    });
  }

  _propsEqual(a, b) {
    if (a.length !== b.length) {
      return false;
    }
    return a.every((p, i) => {
      const q = b[i];
      return (
        p.name === q.name &&
        p.property_type === q.property_type &&
        p.value === q.value
      );
    });
  }

  @action
  deviates(field) {
    if (!this.isRoleplayEdit) {
      return false;
    }
    const char = this.args?.model?.character || {};
    const parent = (key) => char[key];
    if (field === "base_size") {
      const originalSize = parseFloat(parent("base_size") || 0);
      return Math.abs(this.baseSizeInCm - originalSize) > 0.0001;
    }
    if (field === "properties") {
      const orig = Array.isArray(char.properties) ? char.properties : [];
      return !this._propsEqual(this.properties, orig);
    }
    if (field === "triggers") {
      const orig = Array.isArray(char.triggers) ? char.triggers : [];
      return !this._triggersEqual(this.triggers, orig);
    }
    if (field === "blockedItemKeys") {
      const orig = Array.isArray(char.blocked_item_keys)
        ? char.blocked_item_keys
        : [];
      return JSON.stringify(this.blockedItemKeys) !== JSON.stringify(orig);
    }
    const map = {
      infoPost: "info_post",
      showComparison: "show_comparison",
      isMain: "is_main",
    };
    const key = map[field] || field;
    return String(this[field]) !== String(parent(key));
  }

  @action
  resetField(field) {
    const char = this.args?.model?.character || {};
    if (field === "base_size") {
      const originalSize = parseFloat(char.base_size || 170.0);
      this.baseSize = originalSize;
      const unit = getBestUnit(originalSize, this.preferredSystem);
      this.sizeUnit = unit.id;
      this.displaySize = parseFloat(
        (originalSize / unit.factor).toPrecision(5)
      );
      return;
    }
    if (field === "properties") {
      this.properties = (
        Array.isArray(char.properties) ? char.properties : []
      ).map((p) => ({
        ...p,
        _valueUnit: p.property_type === "size" ? "cm" : undefined,
      }));
      return;
    }
    if (field === "triggers") {
      this.triggers = (Array.isArray(char.triggers) ? char.triggers : []).map(
        (t) => ({ ...t })
      );
      return;
    }
    if (field === "blockedItemKeys") {
      this.blockedItemKeys = [
        ...(Array.isArray(char.blocked_item_keys)
          ? char.blocked_item_keys
          : []),
      ];
      return;
    }
    const apiName =
      {
        infoPost: "info_post",
        showComparison: "show_comparison",
        isMain: "is_main",
      }[field] || field;
    if (char[apiName] !== undefined) {
      this[field] = char[apiName];
    }
  }

  get isDirty() {
    const char = this.args?.model?.character || {};
    const ov = this.member?.override_data || {};
    const orig = (key) => ov[key] ?? char[key];
    const origArr = (key) => {
      const ovv = ov[key];
      const cv = char[key];
      return Array.isArray(ovv) ? ovv : Array.isArray(cv) ? cv : [];
    };

    return (
      this.name !== (orig("name") || "") ||
      this.picture !== (orig("picture") || "") ||
      this.infoPost !== (orig("info_post") || "") ||
      this.gender !== (orig("gender") || "") ||
      this.pronouns !== (orig("pronouns") || "") ||
      this.age !== (orig("age") || "") ||
      this.species !== (orig("species") || "") ||
      this.description !== (orig("description") || "") ||
      JSON.stringify(this.blockedItemKeys) !==
        JSON.stringify(origArr("blocked_item_keys")) ||
      JSON.stringify(this.blockedUserIds) !==
        JSON.stringify(origArr("blocked_user_ids")) ||
      this.showComparison !== (orig("show_comparison") ?? true) ||
      this.isMain !== (orig("is_main") || false) ||
      this.characterType !== (char.character_type || "game") ||
      parseFloat(this.displaySize) !== parseFloat(this._initialDisplaySize) ||
      this.sizeUnit !== this._initialSizeUnit ||
      !this._propsEqual(this.properties, origArr("properties")) ||
      !this._triggersEqual(this.triggers, origArr("triggers"))
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
    return this.sizeError !== null && !this.isClampedNotice;
  }

  get resetButtonLabel() {
    return i18n("discourse_size.fields.reset_baseline", {
      size: formatSize(this.baseSize, this.preferredSystem),
    });
  }

  get modalTitle() {
    return this.args?.model?.isNew ? "Create Character" : "Edit Character";
  }

  _checkSize(val) {
    this.isClampedNotice = false;
    if (isNaN(val)) {
      this.sizeError = i18n("discourse_size.fields.invalid_number");
      return;
    }

    if (this.characterType === "game") {
      if (val < this.min) {
        const formattedMin = formatSize(this.min, this.preferredSystem);
        this.sizeError = i18n("discourse_size.fields.min_size_error", {
          size: formattedMin,
        });
      } else if (val > this.max) {
        const formattedMax = formatSize(this.max, this.preferredSystem);
        this.sizeError = i18n("discourse_size.fields.max_size_error", {
          size: formattedMax,
        });
      } else {
        this.sizeError = null;
      }
    } else {
      // Freeform/Roleplay: allow any positive number
      if (val <= 0) {
        this.sizeError = i18n("discourse_size.fields.size_greater_than_zero");
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
  onUnitChange(event) {
    const newUnitId = event?.target ? event.target.value : event;
    const oldUnit = UNITS.find((u) => u.id === this.sizeUnit) || { factor: 1 };
    const newUnit = UNITS.find((u) => u.id === newUnitId) || { factor: 1 };
    const parsed = parseFloat(this.displaySize);
    if (!isNaN(parsed)) {
      const currentCm = parsed * oldUnit.factor;
      this.displaySize = parseFloat(
        (currentCm / newUnit.factor).toPrecision(5)
      );
    }
    this.sizeUnit = newUnitId;
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
        const formattedMin = formatSize(this.min, this.preferredSystem);
        this.sizeError = i18n("discourse_size.fields.clamped_min", {
          size: formattedMin,
        });
        this.isClampedNotice = true;
      } else if (valCm > this.max) {
        this.displaySize = parseFloat((this.max / unit.factor).toPrecision(5));
        const formattedMax = formatSize(this.max, this.preferredSystem);
        this.sizeError = i18n("discourse_size.fields.clamped_max", {
          size: formattedMax,
        });
        this.isClampedNotice = true;
      } else {
        this.displaySize = val;
        this.sizeError = null;
        this.isClampedNotice = false;
      }
    } else {
      this.isClampedNotice = false;
      if (isNaN(valCm) || valCm <= 0) {
        this.displaySize = parseFloat((1.0 / unit.factor).toPrecision(5));
        this.sizeError = i18n("discourse_size.fields.size_greater_than_zero");
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
      if (!file) {
        return;
      }

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

    // For non-game modes, the input shows total size.
    // Convert so base_size + offset = desired total.
    if (this.characterType !== "game" && !this.isRoleplayEdit) {
      const initialTotal =
        this.args?.model?.character?.current_size || this.baseSize;
      const offset = initialTotal - this.baseSize;
      valCm = valCm - offset;
    }

    this.isSaving = true;

    const data = {
      name: this.name,
      picture: this.picture,
      info_post: this.infoPost,
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
      discourse_size_character_properties_attributes: this.properties.map(
        (p) => {
          const attr = {
            name: p.name,
            property_type: p.property_type,
            value: p.value,
          };
          if (p.id) {
            attr.id = p.id;
          }
          if (p._destroy) {
            attr._destroy = true;
          }
          return attr;
        }
      ),
      discourse_size_character_triggers_attributes: this.triggers.map((t) => {
        const attr = {
          name: t.name,
          js_code: t.js_code,
        };
        if (t.id) {
          attr.id = t.id;
        }
        if (t._destroy) {
          attr._destroy = true;
        }
        return attr;
      }),
    };

    try {
      let result;
      if (this.isRoleplayEdit) {
        const char = this.args?.model?.character || {};
        const priorOv = this.member?.override_data || {};
        const changed = (key) => priorOv[key] !== undefined;
        const overrideData = {};

        const _set = (k, cur, orig) => {
          if (cur !== orig) {
            overrideData[k] = cur;
          } else if (priorOv[k] !== undefined) {
            overrideData[k] = null;
          }
        };
        const parentArr = (key) => (Array.isArray(char[key]) ? char[key] : []);
        const priorArr = (key) =>
          Array.isArray(priorOv[key]) ? priorOv[key] : [];
        _set("name", this.name, char.name || "");
        _set("base_size", valCm, char.base_size || 0);
        _set("gender", this.gender, char.gender || "");
        _set("pronouns", this.pronouns, char.pronouns || "");
        _set("age", this.age, char.age || "");
        _set("species", this.species, char.species || "");
        _set("description", this.description, char.description || "");
        _set("picture", this.picture, char.picture || "");
        _set("info_post", this.infoPost, char.info_post || "");
        _set(
          "show_comparison",
          this.showComparison,
          char.show_comparison !== false
        );
        _set("is_main", this.isMain, char.is_main || false);

        if (!this._propsEqual(this.properties, parentArr("properties"))) {
          overrideData.properties = this.properties.map((p) => ({
            name: p.name,
            property_type: p.property_type,
            value: p.value,
            ...(p.id ? { id: p.id } : {}),
            ...(p._destroy ? { _destroy: true } : {}),
          }));
        } else if (priorArr("properties").length > 0) {
          overrideData.properties = null;
        }
        if (!this._triggersEqual(this.triggers, parentArr("triggers"))) {
          overrideData.triggers = this.triggers.map((t) => ({
            name: t.name,
            js_code: t.js_code,
            ...(t.id ? { id: t.id } : {}),
            ...(t._destroy ? { _destroy: true } : {}),
          }));
        } else if (priorArr("triggers").length > 0) {
          overrideData.triggers = null;
        }
        if (
          JSON.stringify(this.blockedItemKeys) !==
          JSON.stringify(parentArr("blocked_item_keys"))
        ) {
          overrideData.blocked_item_keys = this.blockedItemKeys;
        } else if (priorArr("blocked_item_keys").length > 0) {
          overrideData.blocked_item_keys = null;
        }
        const rpId = this.member.roleplay_id;
        await ajax(`/size/roleplays/${rpId}/update_member_overrides`, {
          type: "PUT",
          contentType: "application/json",
          processData: false,
          data: JSON.stringify({ ...overrideData, member_id: this.member.id }),
        });
        result = this.args?.model?.character;
      } else if (this.args?.model?.isNew) {
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
    if (!char) {
      return 0;
    }

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
    if (!confirmed) {
      return;
    }

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

  get isAllGrowingBlocked() {
    return (
      this.blockedItemKeys.includes("__all_growing__") ||
      this.blockedItemKeys.includes("__all__")
    );
  }

  get isAllShrinkingBlocked() {
    return (
      this.blockedItemKeys.includes("__all_shrinking__") ||
      this.blockedItemKeys.includes("__all__")
    );
  }

  get isAllBlocked() {
    return (
      this.blockedItemKeys.includes("__all__") ||
      (this.isAllGrowingBlocked && this.isAllShrinkingBlocked)
    );
  }

  get isNoneBlocked() {
    return this.blockedItemKeys.length === 0;
  }

  get blockingMode() {
    if (this.isAllBlocked) {
      return "all";
    }
    if (this.isAllGrowingBlocked && !this.isAllShrinkingBlocked) {
      return "growing";
    }
    if (this.isAllShrinkingBlocked && !this.isAllGrowingBlocked) {
      return "shrinking";
    }
    if (this.blockedItemKeys.length === 0) {
      return "none";
    }
    return "custom";
  }

  @action
  isItemBlocked(key) {
    if (this.blockedItemKeys.includes("__all__")) {
      return true;
    }
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
    const item = this.availableItems.find((i) => i.key === key);
    const currentlyBlocked = this.isItemBlocked(key);
    let keys = [...this.blockedItemKeys];

    if (currentlyBlocked) {
      // Unblocking this item
      if (keys.includes("__all__")) {
        keys = keys.filter((k) => k !== "__all__");
        if (item?.effect === "grow") {
          keys.push("__all_shrinking__");
          const otherGrowKeys = this.growingItems
            .filter((i) => i.key !== key)
            .map((i) => i.key);
          keys.push(...otherGrowKeys);
          const otherNonGrowOrShrink = this.otherItems
            .filter((i) => i.key !== key)
            .map((i) => i.key);
          keys.push(...otherNonGrowOrShrink);
        } else if (item?.effect === "shrink") {
          keys.push("__all_growing__");
          const otherShrinkKeys = this.shrinkingItems
            .filter((i) => i.key !== key)
            .map((i) => i.key);
          keys.push(...otherShrinkKeys);
          const otherNonGrowOrShrink = this.otherItems
            .filter((i) => i.key !== key)
            .map((i) => i.key);
          keys.push(...otherNonGrowOrShrink);
        } else {
          keys.push("__all_growing__");
          keys.push("__all_shrinking__");
          const otherNonGrowOrShrink = this.otherItems
            .filter((i) => i.key !== key)
            .map((i) => i.key);
          keys.push(...otherNonGrowOrShrink);
        }
      } else if (item?.effect === "grow" && keys.includes("__all_growing__")) {
        keys = keys.filter((k) => k !== "__all_growing__");
        const otherGrowKeys = this.growingItems
          .filter((i) => i.key !== key)
          .map((i) => i.key);
        keys.push(...otherGrowKeys);
      } else if (
        item?.effect === "shrink" &&
        keys.includes("__all_shrinking__")
      ) {
        keys = keys.filter((k) => k !== "__all_shrinking__");
        const otherShrinkKeys = this.shrinkingItems
          .filter((i) => i.key !== key)
          .map((i) => i.key);
        keys.push(...otherShrinkKeys);
      } else {
        keys = keys.filter((k) => k !== key);
      }
    } else {
      // Blocking this item: preserve category tokens!
      if (!keys.includes(key)) {
        keys.push(key);
      }
    }

    this.blockedItemKeys = Array.from(new Set(keys));
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
    let keys = [...this.blockedItemKeys];

    if (keys.includes("__all__")) {
      keys = keys.filter((k) => k !== "__all__");
      keys.push("__all_shrinking__");
    } else if (keys.includes("__all_growing__")) {
      const growKeys = this.growingItems.map((i) => i.key);
      keys = keys.filter(
        (k) => k !== "__all_growing__" && !growKeys.includes(k)
      );
    } else {
      const growKeys = this.growingItems.map((i) => i.key);
      keys = keys.filter((k) => !growKeys.includes(k));
      keys.push("__all_growing__");
    }

    this.blockedItemKeys = Array.from(new Set(keys));
  }

  @action
  blockAllShrinking() {
    let keys = [...this.blockedItemKeys];

    if (keys.includes("__all__")) {
      keys = keys.filter((k) => k !== "__all__");
      keys.push("__all_growing__");
    } else if (keys.includes("__all_shrinking__")) {
      const shrinkKeys = this.shrinkingItems.map((i) => i.key);
      keys = keys.filter(
        (k) => k !== "__all_shrinking__" && !shrinkKeys.includes(k)
      );
    } else {
      const shrinkKeys = this.shrinkingItems.map((i) => i.key);
      keys = keys.filter((k) => !shrinkKeys.includes(k));
      keys.push("__all_shrinking__");
    }

    this.blockedItemKeys = Array.from(new Set(keys));
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
    if (!users || users.length === 0) {
      return;
    }

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

  @action
  addProperty() {
    this.properties = [
      ...this.properties,
      {
        name: "",
        property_type: "text",
        value: "",
      },
    ];
  }

  @action
  addTrigger() {
    this.triggers = [
      ...this.triggers,
      {
        name: "",
        js_code:
          "// character.setSize(character.size() * 1.1);\n// character.grow(10, 60);\n// character.queueSizeAnimation(300, 120);",
      },
    ];
  }

  @action
  removeTrigger(trigger) {
    if (trigger.id) {
      this.triggers = this.triggers.map((t) =>
        t === trigger ? { ...t, _destroy: true } : t
      );
    } else {
      this.triggers = this.triggers.filter((t) => t !== trigger);
    }
  }

  @action
  openTriggerHelp() {
    this.modal.show(DiscourseSizeTriggerHelp);
  }

  @action
  async initCodeMirror(trigger, element) {
    if (!element) {
      return;
    }

    try {
      // 1. Try to load CodeMirror if not present
      if (!window.CodeMirror) {
        try {
          // Try local Discourse module first
          const mod = await import("discourse-common/lib/code-mirror");
          window.CodeMirror = mod.default;
        } catch (e) {
          // Fallback to CDN for reliability
          const CDN_BASE =
            "https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.13";

          if (!document.getElementById("codemirror-css")) {
            const link = document.createElement("link");
            link.id = "codemirror-css";
            link.rel = "stylesheet";
            link.href = `${CDN_BASE}/codemirror.min.css`;
            document.head.appendChild(link);
          }

          // We use standard script injection since loadScript might not be easily imported
          await this._loadExternalScript(`${CDN_BASE}/codemirror.min.js`);
          await this._loadExternalScript(
            `${CDN_BASE}/mode/javascript/javascript.min.js`
          );
        }
      }

      if (window.CodeMirror) {
        this._setupCM(window.CodeMirror, trigger, element);
      } else {
        throw new Error("CodeMirror failed to load");
      }
    } catch (e) {
      console.error("CodeMirror failed to load:", e);
      this._showFallbackTextarea(trigger, element);
    }
  }

  _loadExternalScript(src) {
    return new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = src;
      script.onload = resolve;
      script.onerror = reject;
      document.head.appendChild(script);
    });
  }

  _showFallbackTextarea(trigger, element) {
    const text = document.createElement("textarea");
    text.value = trigger.js_code || "";
    text.className = "trigger-code-fallback";
    text.style.width = "100%";
    text.style.minHeight = "120px";
    text.oninput = (ev) =>
      this.updateTrigger(trigger, "js_code", ev.target.value);
    element.appendChild(text);
  }

  _setupCM(CodeMirror, trigger, element) {
    const editor = CodeMirror(element, {
      value: trigger.js_code || "",
      mode: "javascript",
      lineNumbers: true,
      tabSize: 2,
      lineWrapping: true,
      viewportMargin: Infinity,
    });

    editor.on("change", (cm) => {
      this.updateTrigger(trigger, "js_code", cm.getValue());
    });

    editor.setSize(null, "auto");
    setTimeout(() => editor?.refresh(), 100);
  }

  @action
  resetToDefaultsWithConfirm() {
    this.resetToDefaults();
  }

  @action
  resetToDefaults() {
    const char = this.args?.model?.character || {};
    const parentArr = (key) => (Array.isArray(char[key]) ? char[key] : []);
    this.name = char.name || "";
    this.picture = char.picture || "";
    this.infoPost = char.info_post || "";
    this.gender = char.gender || "";
    this.pronouns = char.pronouns || "";
    this.age = char.age || "";
    this.species = char.species || "";
    this.description = char.description || "";
    this.baseSize = parseFloat(char.base_size || 170.0);
    const unit = getBestUnit(this.baseSize, this.preferredSystem);
    this.sizeUnit = unit.id;
    this.displaySize = parseFloat((this.baseSize / unit.factor).toPrecision(5));
    this.properties = parentArr("properties").map((p) => ({
      ...p,
      _valueUnit: p.property_type === "size" ? "cm" : undefined,
    }));
    this.triggers = parentArr("triggers").map((t) => ({ ...t }));
    this.blockedItemKeys = [...parentArr("blocked_item_keys")];
    const bid = parentArr("blocked_user_ids");
    this.blockedUserIds = bid.map((id) => parseInt(id, 10));
    this.showComparison = char.show_comparison ?? true;
    this.isMain = char.is_main || false;
  }

  @action
  discoverTriggers() {
    const slug = this.siteSettings.discourse_size_trigger_category_slug;
    if (slug) {
      window.open(`/c/${slug}`, "_blank");
    }
  }

  @action
  updateTrigger(trigger, field, value) {
    const newValue = value?.target?.value ?? value;
    trigger[field] = newValue;
    this.triggers = this.triggers.slice();
  }

  <template>
    <DModal
      @title={{this.modalTitle}}
      class="discourse-size-edit-character-modal"
    >
      <:body>
        {{! template-lint-disable no-invalid-interactive }}
        <div onkeydown={{this.onKeyDown}}>
          <div class="control-group">
            <label>{{i18n "discourse_size.modes.title"}}</label>
            {{#if @model.isNew}}
              <span class="instructions">{{i18n
                  "discourse_size.modes.help"
                }}</span>
              <div class="type-selection">
                <label class="radio-label">
                  <input
                    type="radio"
                    name="char_type"
                    value="game"
                    checked={{eq this.characterType "game"}}
                    {{on "change" (fn this.setCharType "game")}}
                  />
                  <span><strong>{{i18n
                        "discourse_size.modes.game_name"
                      }}</strong>:
                    {{i18n "discourse_size.modes.game_desc"}}</span>
                </label>
                <label class="radio-label">
                  <input
                    type="radio"
                    name="char_type"
                    value="normal"
                    checked={{eq this.characterType "normal"}}
                    {{on "change" (fn this.setCharType "normal")}}
                  />
                  <span><strong>{{i18n
                        "discourse_size.modes.normal_name"
                      }}</strong>:
                    {{i18n "discourse_size.modes.normal_desc"}}</span>
                </label>
              </div>
            {{else}}
              <div class="type-display">
                <span class="mode-label">Mode:</span>
                <strong>
                  {{#if (eq this.characterType "game")}}
                    {{i18n "discourse_size.modes.game_name"}}
                  {{else}}
                    {{i18n "discourse_size.modes.normal_name"}}
                  {{/if}}
                </strong>
                <span class="instructions">{{i18n
                    "discourse_size.modes.cannot_change"
                  }}</span>
              </div>
            {{/if}}
          </div>

          <hr />

          <div class="control-group">
            <label>
              {{i18n "discourse_size.fields.name"}}
              {{#if this.isRoleplayEdit}}
                {{#if (this.deviates "name")}}
                  <DButton
                    @action={{fn this.resetField "name"}}
                    @icon="clock-rotate-left"
                    class="btn-small btn-default"
                    @title="discourse_size.roleplays.reset_field"
                  />
                {{/if}}
              {{/if}}
            </label>
            <span class="instructions">{{i18n
                "discourse_size.fields.name_help"
              }}</span>
            <Input @type="text" @value={{this.name}} />
          </div>

          <div class="control-group">
            <label>
              {{i18n "discourse_size.fields.picture"}}
              {{#if this.isRoleplayEdit}}
                {{#if (this.deviates "picture")}}
                  <DButton
                    @action={{fn this.resetField "picture"}}
                    @icon="clock-rotate-left"
                    class="btn-small btn-default"
                    @title="discourse_size.roleplays.reset_field"
                  />
                {{/if}}
              {{/if}}
            </label>
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

          <div class="wide-control-group">
            <div class="control-group">
              <label>
                {{i18n "discourse_size.gender"}}
                {{#if this.isRoleplayEdit}}
                  {{#if (this.deviates "gender")}}
                    <DButton
                      @action={{fn this.resetField "gender"}}
                      @icon="clock-rotate-left"
                      class="btn-small btn-default"
                      @title="discourse_size.roleplays.reset_field"
                    />
                  {{/if}}
                {{/if}}
              </label>
              <Input
                @type="text"
                @value={{this.gender}}
                placeholder={{i18n "discourse_size.gender_placeholder"}}
              />
            </div>

            <div class="control-group">
              <label>
                {{i18n "discourse_size.pronouns"}}
                {{#if this.isRoleplayEdit}}
                  {{#if (this.deviates "pronouns")}}
                    <DButton
                      @action={{fn this.resetField "pronouns"}}
                      @icon="clock-rotate-left"
                      class="btn-small btn-default"
                      @title="discourse_size.roleplays.reset_field"
                    />
                  {{/if}}
                {{/if}}
              </label>
              <Input
                @type="text"
                @value={{this.pronouns}}
                placeholder="e.g. He/Him, She/Her, They/Them"
              />
            </div>

            <div class="control-group">
              <label>
                {{i18n "discourse_size.age"}}
                {{#if this.isRoleplayEdit}}
                  {{#if (this.deviates "age")}}
                    <DButton
                      @action={{fn this.resetField "age"}}
                      @icon="clock-rotate-left"
                      class="btn-small btn-default"
                      @title="discourse_size.roleplays.reset_field"
                    />
                  {{/if}}
                {{/if}}
              </label>
              <Input
                @type="text"
                @value={{this.age}}
                placeholder="e.g. 25, Young Adult, Adult"
              />
            </div>

            <div class="control-group">
              <label>
                {{i18n "discourse_size.species"}}
                {{#if this.isRoleplayEdit}}
                  {{#if (this.deviates "species")}}
                    <DButton
                      @action={{fn this.resetField "species"}}
                      @icon="clock-rotate-left"
                      class="btn-small btn-default"
                      @title="discourse_size.roleplays.reset_field"
                    />
                  {{/if}}
                {{/if}}
              </label>
              <Input
                @type="text"
                @value={{this.species}}
                placeholder="e.g. Human, Elf, Dragon"
              />
            </div>
          </div>

          <div class="control-group">
            <label>
              {{i18n "discourse_size.description"}}
              {{#if this.isRoleplayEdit}}
                {{#if (this.deviates "description")}}
                  <DButton
                    @action={{fn this.resetField "description"}}
                    @icon="clock-rotate-left"
                    class="btn-small btn-default"
                    @title="discourse_size.roleplays.reset_field"
                  />
                {{/if}}
              {{/if}}
            </label>
            <span class="instructions">{{i18n
                "discourse_size.fields.description_help"
              }}</span>
            <Textarea
              @value={{this.description}}
              class="character-description-input"
            />
          </div>

          <div class="control-group">
            <label>
              {{i18n "discourse_size.fields.info_url"}}
              {{#if this.isRoleplayEdit}}
                {{#if (this.deviates "infoPost")}}
                  <DButton
                    @action={{fn this.resetField "infoPost"}}
                    @icon="clock-rotate-left"
                    class="btn-small btn-default"
                    @title="discourse_size.roleplays.reset_field"
                  />
                {{/if}}
              {{/if}}
            </label>
            <span class="instructions">{{i18n
                "discourse_size.fields.info_url_help"
              }}</span>
            <Input
              @type="text"
              @value={{this.infoPost}}
              placeholder="https://..."
              class="info-post-input"
            />
          </div>

          <hr />

          <div class="control-group">
            <label>{{if
                (eq this.characterType "normal")
                (i18n "discourse_size.fields.size")
                (i18n "discourse_size.fields.base_size")
              }}
              {{#if this.isRoleplayEdit}}
                {{#if (this.deviates "base_size")}}
                  <DButton
                    @action={{fn this.resetField "base_size"}}
                    @icon="clock-rotate-left"
                    class="btn-small btn-default"
                    @title="discourse_size.roleplays.reset_field"
                  />
                {{/if}}
              {{/if}}
            </label>
            <span class="instructions">{{if
                (eq this.characterType "normal")
                (i18n "discourse_size.fields.size_help")
                (i18n "discourse_size.fields.base_size_help")
              }}</span>
            <div class="size-input-wrapper">
              <input
                type="number"
                value={{this.displaySize}}
                step="0.0001"
                class="base-size-input"
                {{on "input" this.onBaseSizeInput}}
                {{on "blur" this.onBaseSizeBlur}}
              />
              <select
                class="size-unit-selector"
                {{on "change" this.onUnitChange}}
              >
                {{#each this.units as |unit|}}
                  <option
                    value={{unit.id}}
                    selected={{eq this.sizeUnit unit.id}}
                  >
                    {{unit.name}}
                  </option>
                {{/each}}
              </select>
            </div>
            {{#if this.sizeError}}
              <div class="inline-error">{{this.sizeError}}</div>
            {{/if}}
          </div>

          <hr />

          {{#unless this.siteSettings.discourse_size_disable_properties}}
            <div class="control-group custom-properties-group">
              <label>
                {{i18n "discourse_size.properties.title"}}
                {{#if this.isRoleplayEdit}}
                  {{#if (this.deviates "properties")}}
                    <DButton
                      @action={{fn this.resetField "properties"}}
                      @icon="clock-rotate-left"
                      class="btn-small btn-default"
                      @title="discourse_size.roleplays.reset_field"
                    />
                  {{/if}}
                {{/if}}
              </label>
              <span class="instructions">{{i18n
                  "discourse_size.properties.instructions"
                }}</span>

              <div class="properties-list">
                {{#each this.properties as |prop|}}
                  {{#unless prop._destroy}}
                    <div class="property-item">
                      <div class="property-row">
                        <Input
                          @type="text"
                          @value={{prop.name}}
                          placeholder={{i18n
                            "discourse_size.properties.name_placeholder"
                          }}
                          class="prop-name"
                          {{on "input" (fn this.updateProperty prop "name")}}
                        />
                        <select
                          class="prop-type"
                          {{on "change" (fn this.onPropertyTypeChange prop)}}
                        >
                          <option
                            value="text"
                            selected={{eq prop.property_type "text"}}
                          >{{i18n
                              "discourse_size.properties.types.text"
                            }}</option>
                          <option
                            value="number"
                            selected={{eq prop.property_type "number"}}
                          >{{i18n
                              "discourse_size.properties.types.number"
                            }}</option>
                          <option
                            value="size"
                            selected={{eq prop.property_type "size"}}
                          >{{i18n
                              "discourse_size.properties.types.size"
                            }}</option>
                        </select>
                        <DButton
                          @action={{fn this.removeProperty prop}}
                          @icon="trash-can"
                          class="btn-danger btn-small remove-prop-btn"
                        />
                      </div>
                      <div class="property-row second-row">
                        {{#if (eq prop.property_type "size")}}
                          <input
                            type="number"
                            value={{this.getPropDisplayValue prop}}
                            step="0.01"
                            class="prop-value prop-value-size"
                            placeholder={{i18n
                              "discourse_size.properties.value_placeholder"
                            }}
                            {{on "input" (fn this.onSizePropValueInput prop)}}
                          />
                          <select
                            class="prop-value-unit"
                            {{on "change" (fn this.onSizePropUnitChange prop)}}
                          >
                            {{#each this.units as |unit|}}
                              <option
                                value={{unit.id}}
                                selected={{eq prop._valueUnit unit.id}}
                              >{{unit.name}}</option>
                            {{/each}}
                          </select>
                        {{else}}
                          <Input
                            @type="text"
                            @value={{prop.value}}
                            placeholder={{i18n
                              "discourse_size.properties.value_placeholder"
                            }}
                            class="prop-value"
                            {{on "input" (fn this.updateProperty prop "value")}}
                          />
                        {{/if}}
                      </div>

                    </div>
                  {{/unless}}
                {{/each}}
              </div>

              <DButton
                @action={{this.addProperty}}
                @label="discourse_size.properties.add_property"
                @icon="plus"
                class="btn-default add-prop-btn"
              />
            </div>
          {{/unless}}

          <hr />

          {{#if (notEq this.characterType "game")}}
            {{#unless this.siteSettings.discourse_size_disable_triggers}}
              <div class="control-group custom-triggers-group">
                <div class="triggers-header-row">
                  <label>
                    {{i18n "discourse_size.triggers.title"}}
                    {{#if this.isRoleplayEdit}}
                      {{#if (this.deviates "triggers")}}
                        <DButton
                          @action={{fn this.resetField "triggers"}}
                          @icon="clock-rotate-left"
                          class="btn-small btn-default"
                          @title="discourse_size.roleplays.reset_field"
                        />
                      {{/if}}
                    {{/if}}
                  </label>
                  <DButton
                    @action={{this.openTriggerHelp}}
                    @icon="question"
                    @label="discourse_size.triggers.help_btn"
                    class="btn-default btn-small btn-default"
                  />
                </div>
                <span class="instructions">{{i18n
                    "discourse_size.triggers.instructions"
                  }}</span>

                <div class="triggers-list">
                  {{#each this.triggers as |trigger|}}
                    {{#unless trigger._destroy}}
                      <div class="trigger-item">
                        <div class="trigger-header">
                          <Input
                            @type="text"
                            @value={{trigger.name}}
                            placeholder={{i18n
                              "discourse_size.triggers.name_placeholder"
                            }}
                            {{on
                              "input"
                              (fn this.updateTrigger trigger "name")
                            }}
                            class="trigger-name"
                          />
                          <DButton
                            @action={{fn this.removeTrigger trigger}}
                            @icon="trash-can"
                            class="btn-danger btn-small remove-trigger-btn"
                          />
                        </div>
                        <div {{didInsert (fn this.initCodeMirror trigger)}}>
                        </div>
                      </div>
                    {{/unless}}
                  {{/each}}
                </div>

                <DButton
                  @action={{this.addTrigger}}
                  @label="discourse_size.triggers.add_trigger"
                  @icon="plus"
                  class="btn-default add-trigger-btn"
                />
                {{#if this.siteSettings.discourse_size_trigger_category_slug}}
                  <DButton
                    @action={{this.discoverTriggers}}
                    class="btn-default discover-triggers-btn"
                  >
                    {{icon "compass"}}
                    {{i18n "discourse_size.triggers.discover_triggers"}}
                  </DButton>
                {{/if}}
              </div>

              <hr />
            {{/unless}}
          {{/if}}

          {{#if (eq this.characterType "game")}}
            <div class="control-group blocking-items-group">
              <label>{{i18n "discourse_size.blocking.block_items"}}</label>
              <span class="instructions">{{i18n
                  "discourse_size.blocking.select_items_to_block"
                }}</span>
              <div class="bulk-buttons">
                <DButton
                  @action={{this.blockAll}}
                  @label="discourse_size.blocking.block_all"
                  class="btn-small
                    {{if this.isAllBlocked 'btn-primary' 'btn-default'}}"
                />
                <DButton
                  @action={{this.blockNone}}
                  @label="discourse_size.blocking.block_none"
                  class="btn-small
                    {{if this.isNoneBlocked 'btn-primary' 'btn-default'}}"
                />
                <DButton
                  @action={{this.blockAllGrowing}}
                  @label="discourse_size.blocking.block_all_growing"
                  class="btn-small
                    {{if this.isAllGrowingBlocked 'btn-primary' 'btn-default'}}"
                />
                <DButton
                  @action={{this.blockAllShrinking}}
                  @label="discourse_size.blocking.block_all_shrinking"
                  class="btn-small
                    {{if
                      this.isAllShrinkingBlocked
                      'btn-primary'
                      'btn-default'
                    }}"
                />
              </div>

              {{#if this.growingItems.length}}
                <div class="blocking-section">
                  <span class="section-title">{{i18n
                      "discourse_size.blocking.growing_items"
                    }}</span>
                  <div class="blocking-items-grid">
                    {{#each this.growingItems as |item|}}
                      <label
                        class="blocking-item-card
                          {{if (this.isItemBlocked item.key) 'blocked'}}"
                      >
                        <input
                          type="checkbox"
                          checked={{this.isItemBlocked item.key}}
                          {{on "change" (fn this.toggleItemBlock item.key)}}
                        />
                        <span>{{item.name}}</span>
                      </label>
                    {{/each}}
                  </div>
                </div>
              {{/if}}

              {{#if this.shrinkingItems.length}}
                <div class="blocking-section">
                  <span class="section-title">{{i18n
                      "discourse_size.blocking.shrinking_items"
                    }}</span>
                  <div class="blocking-items-grid">
                    {{#each this.shrinkingItems as |item|}}
                      <label
                        class="blocking-item-card
                          {{if (this.isItemBlocked item.key) 'blocked'}}"
                      >
                        <input
                          type="checkbox"
                          checked={{this.isItemBlocked item.key}}
                          {{on "change" (fn this.toggleItemBlock item.key)}}
                        />
                        <span>{{item.name}}</span>
                      </label>
                    {{/each}}
                  </div>
                </div>
              {{/if}}

              {{#if this.otherItems.length}}
                <div class="blocking-section">
                  <span class="section-title">{{i18n
                      "discourse_size.blocking.other_items"
                    }}</span>
                  <div class="blocking-items-grid">
                    {{#each this.otherItems as |item|}}
                      <label
                        class="blocking-item-card
                          {{if (this.isItemBlocked item.key) 'blocked'}}"
                      >
                        <input
                          type="checkbox"
                          checked={{this.isItemBlocked item.key}}
                          {{on "change" (fn this.toggleItemBlock item.key)}}
                        />
                        <span>{{item.name}}</span>
                      </label>
                    {{/each}}
                  </div>
                </div>
              {{/if}}
            </div>

            <div class="control-group blocking-users-group">
              <label>{{i18n
                  "discourse_size.blocking.blocked_users_list"
                }}</label>
              <div class="user-search-wrapper">
                <EmailGroupUserChooser
                  @onChange={{this.onUserSelected}}
                  @options={{hash maximum=1}}
                  @placeholderKey="discourse_size.blocking.username_placeholder"
                />
              </div>

              {{#if this.blockedUsers.length}}
                <div class="blocked-users-list">
                  {{#each this.blockedUsers as |user|}}
                    <div class="blocked-user-item">
                      <div class="user-info">
                        {{avatar user imageSize="small"}}
                        <span class="username">{{user.username}}</span>
                      </div>
                      <DButton
                        @action={{fn this.unblockUser user.id}}
                        @label="discourse_size.blocking.unblock_user"
                        class="btn-flat btn-danger unblock-btn"
                      />
                    </div>
                  {{/each}}
                </div>
              {{else}}
                <div class="empty-notice">{{i18n
                    "discourse_size.blocking.no_blocked_users"
                  }}</div>
              {{/if}}
            </div>

            <hr />
          {{/if}}

          <div class="control-group checkbox-group">
            <label>{{i18n "discourse_size.options.title"}}</label>

            <div class="control-group checkbox-group">
              <label>
                <div>
                  <Input @type="checkbox" @checked={{this.showComparison}} />
                  {{i18n "discourse_size.options.show_comparison"}}
                </div>
                {{#if this.isRoleplayEdit}}
                  {{#if (this.deviates "showComparison")}}
                    <DButton
                      @action={{fn this.resetField "showComparison"}}
                      @icon="clock-rotate-left"
                      class="btn-small btn-default"
                      @title="discourse_size.roleplays.reset_field"
                    />
                  {{/if}}
                {{/if}}
              </label>
            </div>

            {{#unless this.isRoleplayEdit}}
              <div class="control-group checkbox-group">
                <label>
                  <div>
                    <Input @type="checkbox" @checked={{this.isMain}} />
                    {{i18n "discourse_size.options.is_main"}}
                  </div>
                </label>
                <span class="instructions">
                  {{i18n "discourse_size.options.is_main_help"}}
                </span>
              </div>
            {{/unless}}
          </div>

        </div>
      </:body>
      <:footer>
        <DButton
          @action={{this.save}}
          @label="discourse_size.save"
          @disabled={{or this.isSaving this.isInvalid}}
          class="btn-primary"
        />
        <DButton
          @action={{this.close}}
          @label="discourse_size.cancel"
          class="btn-default"
        />
        {{#if this.isRoleplayEdit}}
          <DButton
            @action={{this.resetToDefaultsWithConfirm}}
            @label="discourse_size.roleplays.reset_to_defaults"
            class="btn-default"
          />
        {{/if}}
        {{#unless @model.isNew}}
          <DButton
            @action={{this.deleteCharacter}}
            @label="discourse_size.delete"
            class="btn-danger modal-delete-btn"
          />
        {{/unless}}
      </:footer>
    </DModal>
  </template>
}
