import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import I18n from "I18n";

export default class DiscourseSizeEditShopItem extends Component {
  @tracked itemData = {
    key: "",
    name: "",
    description: "",
    price: 0,
    effect: "grow",
    amount: 10,
    duration_minutes: 60,
    uses: 1,
    picture: "",
    stock: -1,
    enabled: true,
  };
  @tracked isSaving = false;

  constructor() {
    super(...arguments);
    if (this.args.model.item) {
      this.itemData = { ...this.args.model.item };
    }
  }

  get effectOptions() {
    return [
      { id: "grow", name: "Grow" },
      { id: "shrink", name: "Shrink" },
    ];
  }

  @action
  updateValue(path, value) {
    const parts = path.split(".");
    if (parts.length === 1) {
      this[path] = value;
    } else {
      let current = this;
      for (let i = 0; i < parts.length - 1; i++) {
        current = current[parts[i]];
      }
      current[parts[parts.length - 1]] = value;
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
        this.updateValue("itemData.picture", result.url);
      } catch (err) {
        alert("Error uploading image");
      }
    };
    fileInput.click();
  }

  @action
  async save() {
    this.isSaving = true;
    const isNew = !this.args.model.item;
    const url = isNew
      ? "/size/admin/shop_items"
      : `/size/admin/shop_items/${this.args.model.item.id}`;
    const type = isNew ? "POST" : "PUT";

    try {
      await ajax(url, {
        type,
        data: this.itemData,
      });
      this.args.model.onSave?.();
      this.args.closeModal?.();
    } catch (e) {
      alert("Error saving item");
    } finally {
      this.isSaving = false;
    }
  }

  @action
  async deleteItem() {
    if (
      !confirm(I18n.t("discourse_size.shop.delete_confirm"))
    ) {
      return;
    }

    try {
      await ajax(`/size/admin/shop_items/${this.args.model.item.id}`, {
        type: "DELETE",
      });
      this.args.model.onSave?.();
      this.args.closeModal?.();
    } catch (e) {
      alert("Error deleting item");
    }
  }
}
