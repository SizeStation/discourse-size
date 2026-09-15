import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input, Textarea } from "@ember/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

const DEFAULT_ITEM_DATA = {
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
  self_effect: null,
  self_amount: 0,
  can_only_use_on_others: false,
  can_only_use_on_self: false,
  warning_text: "",
};

export default class DiscourseSizeEditShopItem extends Component {
  @tracked itemData;
  @tracked isSaving = false;

  constructor() {
    super(...arguments);
    const item = this.args.model?.item;
    this.itemData = {
      ...DEFAULT_ITEM_DATA,
      ...(item || {}),
      self_effect:
        item?.self_effect === "" ? null : (item?.self_effect ?? null),
      can_only_use_on_self: Boolean(item?.can_only_use_on_self),
      can_only_use_on_others: Boolean(item?.can_only_use_on_others),
      warning_text: item?.warning_text ?? "",
      self_amount: item?.self_amount ?? 0,
    };
  }

  get effectOptions() {
    return [
      { id: "grow", name: "Grow" },
      { id: "shrink", name: "Shrink" },
      { id: "static", name: "Static" },
    ];
  }

  get selfEffectOptions() {
    return [
      { id: null, name: "None" },
      { id: "grow", name: "Grow Self" },
      { id: "shrink", name: "Shrink Self" },
      { id: "static", name: "Static Self" },
    ];
  }

  @action
  updateValue(path, value) {
    const parts = path.split(".");
    if (parts.length === 1) {
      this[path] = value;
    } else if (parts[0] === "itemData") {
      this.itemData = { ...this.itemData, [parts[1]]: value };
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
    const isNew = !this.args.model.item?.id;
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
    if (!confirm(i18n("discourse_size.shop.delete_confirm"))) {
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

  <template>
    <DModal
      @title={{if
        @model.item
        (i18n "discourse_size.shop.edit_item")
        (i18n "discourse_size.shop.add_item")
      }}
      @closeModal={{@closeModal}}
      class="discourse-size-edit-shop-item-modal"
    >
      <:body>
        <div class="edit-shop-item-form">
          <div class="control-group">
            <label>{{i18n "discourse_size.shop.fields.key"}}</label>
            <Input @value={{this.itemData.key}} />
          </div>

          <div class="control-group">
            <label>{{i18n "discourse_size.shop.fields.name"}}</label>
            <Input @value={{this.itemData.name}} />
          </div>

          <div class="control-group">
            <label>{{i18n "discourse_size.shop.fields.description"}}</label>
            <Textarea
              @value={{this.itemData.description}}
              class="description-input"
            />
          </div>

          <div class="control-group half">
            <label>{{i18n "discourse_size.shop.fields.enabled"}}</label>
            <label class="checkbox-label">
              <Input @type="checkbox" @checked={{this.itemData.enabled}} />
              {{i18n "discourse_size.shop.fields.is_enabled"}}
            </label>
          </div>

          <div class="row">
            <div class="control-group half">
              <label>{{i18n "discourse_size.shop.fields.price"}}</label>
              <Input @type="number" @value={{this.itemData.price}} />
            </div>
            <div class="control-group half">
              <label>{{i18n "discourse_size.shop.fields.stock"}}</label>
              <Input @type="number" @value={{this.itemData.stock}} />
            </div>
          </div>

          <div class="row">
            <div class="control-group half">
              <label>{{i18n "discourse_size.shop.fields.effect"}}</label>
              <ComboBox
                @content={{this.effectOptions}}
                @value={{this.itemData.effect}}
                @onChange={{fn this.updateValue "itemData.effect"}}
              />
            </div>
            <div class="control-group half">
              <label>{{i18n "discourse_size.shop.fields.amount"}}</label>
              <Input @type="number" @value={{this.itemData.amount}} />
            </div>
          </div>

          <div class="row">
            <div class="control-group half">
              <label>{{i18n "discourse_size.shop.fields.self_effect"}}</label>
              <ComboBox
                @content={{this.selfEffectOptions}}
                @value={{this.itemData.self_effect}}
                @onChange={{fn this.updateValue "itemData.self_effect"}}
              />
            </div>
            <div class="control-group half">
              <label>{{i18n "discourse_size.shop.fields.self_amount"}}</label>
              <Input @type="number" @value={{this.itemData.self_amount}} />
            </div>
          </div>

          <div class="row">
            <div class="control-group half">
              <label>{{i18n "discourse_size.shop.fields.duration"}}</label>
              <Input @type="number" @value={{this.itemData.duration_minutes}} />
            </div>
            <div class="control-group half">
              <label>{{i18n "discourse_size.shop.fields.uses"}}</label>
              <Input @type="number" @value={{this.itemData.uses}} />
            </div>
          </div>

          <div class="control-group">
            <label>{{i18n "discourse_size.shop.fields.picture"}}</label>
            <div class="picture-upload-wrapper">
              {{#if this.itemData.picture}}
                <img
                  src={{this.itemData.picture}}
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
            <label>{{i18n "discourse_size.shop.fields.warning_text"}}</label>
            <Input @value={{this.itemData.warning_text}} />
          </div>

          <div class="control-group checkbox">
            <label>
              <Input
                @type="checkbox"
                @checked={{this.itemData.can_only_use_on_others}}
              />
              {{i18n "discourse_size.shop.fields.can_only_use_on_others"}}
            </label>
          </div>

          <div class="control-group checkbox">
            <label>
              <Input
                @type="checkbox"
                @checked={{this.itemData.can_only_use_on_self}}
              />
              {{i18n "discourse_size.shop.fields.can_only_use_on_self"}}
            </label>
          </div>

        </div>
      </:body>
      <:footer>
        <DButton
          @label="discourse_size.save"
          @action={{this.save}}
          @disabled={{this.isSaving}}
          class="btn-primary"
        />
        {{#if @model.item}}
          <DButton
            @label="discourse_size.shop.delete_item"
            @action={{this.deleteItem}}
            class="btn-danger"
          />
        {{/if}}
        <DButton
          @label="discourse_size.cancel"
          @action={{@closeModal}}
          class="btn-flat"
        />
      </:footer>
    </DModal>
  </template>
}
