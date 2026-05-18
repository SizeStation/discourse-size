import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { UNITS, getBestUnit } from "../../lib/size-formatter";
import DiscourseSizeTriggerHelp from "./discourse-size-trigger-help";

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
  @tracked properties = [];
  @tracked triggers = [];

  @service currentUser;
  @service siteSettings;
  @service modal;

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
    this.baseSize = ov.base_size != null ? parseFloat(ov.base_size) : (char.base_size || 170.0);
    this.isMain = ov.is_main ?? (char.is_main || false);
    this.characterType = char.character_type || "game";
    this.showComparison = ov.show_comparison ?? (char.show_comparison !== false);
    this.blockedItemKeys = Array.isArray(ov.blocked_item_keys) ? ov.blocked_item_keys : (char.blocked_item_keys || []);
    this.blockedUserIds = ((ov.blocked_user_ids ?? char.blocked_user_ids) || []).map((id) =>
      parseInt(id, 10)
    );
    this.blockedUsers = char.blocked_users || [];
    this.properties = ((Array.isArray(ov.properties) ? ov.properties : (char.properties || []))).map((p) => ({
      ...p,
      _valueUnit: p.property_type === "size" ? "cm" : undefined,
    }));
    this.triggers = (Array.isArray(ov.triggers) ? ov.triggers : (char.triggers || [])).map((t) => ({ ...t }));

    if (this.characterType === "game") {
      this.fetchAvailableItems();
    }

    const initialSize = this.baseSize;
    const unit = getBestUnit(initialSize);
    this.sizeUnit = unit.id;
    this.displaySize = parseFloat((initialSize / unit.factor).toPrecision(5));

    this._initialDisplaySize = this.displaySize;
    this._initialSizeUnit = this.sizeUnit;
  }

  get isRoleplayEdit() {
    return !!this.member;
  }

  _triggersEqual(a, b) {
    if (a.length !== b.length) return false;
    return a.every((t, i) => {
      const u = b[i];
      return t.name === u.name && t.js_code === u.js_code && t._destroy === u._destroy;
    });
  }

  _propsEqual(a, b) {
    if (a.length !== b.length) return false;
    return a.every((p, i) => {
      const q = b[i];
      return p.name === q.name && p.property_type === q.property_type && p.value === q.value;
    });
  }

  @action
  deviates(field) {
    if (!this.isRoleplayEdit) return false;
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
      const orig = Array.isArray(char.blocked_item_keys) ? char.blocked_item_keys : [];
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
      const unit = getBestUnit(originalSize);
      this.sizeUnit = unit.id;
      this.displaySize = parseFloat((originalSize / unit.factor).toPrecision(5));
      return;
    }
    if (field === "properties") {
      this.properties = (Array.isArray(char.properties) ? char.properties : []).map((p) => ({
        ...p,
        _valueUnit: p.property_type === "size" ? "cm" : undefined,
      }));
      return;
    }
    if (field === "triggers") {
      this.triggers = (Array.isArray(char.triggers) ? char.triggers : []).map((t) => ({ ...t }));
      return;
    }
    if (field === "blockedItemKeys") {
      this.blockedItemKeys = [...(Array.isArray(char.blocked_item_keys) ? char.blocked_item_keys : [])];
      return;
    }
    const apiName = {
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
      return Array.isArray(ovv) ? ovv : (Array.isArray(cv) ? cv : []);
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
      // Freeform/Roleplay: allow any positive number
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

    // For non-game modes, the input shows total size.
    // Convert so base_size + offset = desired total.
    if (this.characterType !== "game" && !this.isRoleplayEdit) {
      const initialTotal = this.args?.model?.character?.current_size || this.baseSize;
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
          if (p.id) attr.id = p.id;
          if (p._destroy) attr._destroy = true;
          return attr;
        }
      ),
      discourse_size_character_triggers_attributes: this.triggers.map((t) => {
        const attr = {
          name: t.name,
          js_code: t.js_code,
        };
        if (t.id) attr.id = t.id;
        if (t._destroy) attr._destroy = true;
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
          if (cur !== orig) overrideData[k] = cur;
          else if (priorOv[k] !== undefined) overrideData[k] = null;
        };
        const parentArr = (key) => Array.isArray(char[key]) ? char[key] : [];
        const priorArr = (key) => Array.isArray(priorOv[key]) ? priorOv[key] : [];
        _set("name", this.name, char.name || "");
        _set("base_size", valCm, char.base_size || 0);
        _set("gender", this.gender, char.gender || "");
        _set("pronouns", this.pronouns, char.pronouns || "");
        _set("age", this.age, char.age || "");
        _set("species", this.species, char.species || "");
        _set("description", this.description, char.description || "");
        _set("picture", this.picture, char.picture || "");
        _set("info_post", this.infoPost, char.info_post || "");
        _set("show_comparison", this.showComparison, char.show_comparison !== false);
        _set("is_main", this.isMain, char.is_main || false);

        if (!this._propsEqual(this.properties, parentArr("properties"))) {
          overrideData.properties = this.properties.map((p) => ({
            name: p.name, property_type: p.property_type, value: p.value,
            ...(p.id ? { id: p.id } : {}),
            ...(p._destroy ? { _destroy: true } : {}),
          }));
        } else if (priorArr("properties").length > 0) {
          overrideData.properties = null;
        }
        if (!this._triggersEqual(this.triggers, parentArr("triggers"))) {
          overrideData.triggers = this.triggers.map((t) => ({
            name: t.name, js_code: t.js_code,
            ...(t.id ? { id: t.id } : {}),
            ...(t._destroy ? { _destroy: true } : {}),
          }));
        } else if (priorArr("triggers").length > 0) {
          overrideData.triggers = null;
        }
        if (JSON.stringify(this.blockedItemKeys) !== JSON.stringify(parentArr("blocked_item_keys"))) {
          overrideData.blocked_item_keys = this.blockedItemKeys;
        } else if (priorArr("blocked_item_keys").length > 0) {
          overrideData.blocked_item_keys = null;
        }
        const rpId = this.member.roleplay_id;
        await ajax(
          `/size/roleplays/${rpId}/update_member_overrides`,
          {
            type: "PUT",
            contentType: "application/json",
            processData: false,
            data: JSON.stringify({ ...overrideData, member_id: this.member.id })
          }
        );
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
        js_code: "// character.setSize(character.size() * 1.1);\n// character.grow(10, 60);\n// character.queueSizeAnimation(300, 120);",
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
    if (!element) return;

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
    const parentArr = (key) => Array.isArray(char[key]) ? char[key] : [];
    this.name = char.name || "";
    this.picture = char.picture || "";
    this.infoPost = char.info_post || "";
    this.gender = char.gender || "";
    this.pronouns = char.pronouns || "";
    this.age = char.age || "";
    this.species = char.species || "";
    this.description = char.description || "";
    this.baseSize = parseFloat(char.base_size || 170.0);
    const unit = getBestUnit(this.baseSize);
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
}
