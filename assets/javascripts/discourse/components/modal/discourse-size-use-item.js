import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import I18n from "I18n";

export default class DiscourseSizeUseItem extends Component {
  @service siteSettings;
  @service currentUser;
  @tracked inventory = [];
  @tracked loading = true;

  constructor() {
    super(...arguments);
    this.fetchInventory();
  }

  get title() {
    return I18n.t("discourse_size.inventory.use_item_on", {
      name: this.args.model.character.name,
    });
  }

  get filteredInventory() {
    return this.inventory.filter((item) => !this.isBlocked(item));
  }

  get blockedInventoryNames() {
    const names = this.inventory
      .filter((item) => this.isBlocked(item))
      .map((item) => item.details.name);
    return [...new Set(names)];
  }

  get hasNoUsableItems() {
    return (
      !this.loading &&
      this.inventory.length > 0 &&
      this.filteredInventory.length === 0
    );
  }

  isBlocked(item) {
    const char = this.args.model.character;
    if (!char) return true;

    // Owner/Admin is never blocked
    if (this.currentUser?.id === char.user_id || this.currentUser?.admin) {
      return false;
    }

    const blockedKeys = char.blocked_item_keys || [];
    const itemKey = item.details.key;
    const effect = item.details.effect;

    if (blockedKeys.includes("__all__")) return true;
    if (blockedKeys.includes(itemKey)) return true;
    if (effect === "grow" && blockedKeys.includes("__all_growing__"))
      return true;
    if (effect === "shrink" && blockedKeys.includes("__all_shrinking__"))
      return true;

    return false;
  }

  async fetchInventory() {
    this.loading = true;
    try {
      const result = await ajax("/size/inventory");
      this.inventory = result.inventory;
    } catch (e) {
      // Error
    } finally {
      this.loading = false;
    }
  }

  @action
  async useItem(item) {
    if (
      !confirm(
        I18n.t("discourse_size.inventory.use_confirm", {
          name: item.details.name,
        })
      )
    ) {
      return;
    }

    try {
      const result = await ajax("/size/inventory/use", {
        type: "POST",
        data: {
          inventory_item_id: item.id,
          character_id: this.args.model.character.id,
        },
      });

      if (result.success) {
        this.args.model.onAction?.(result);
        this.args.closeModal();
      }
    } catch (e) {
      alert(e.jqXHR?.responseJSON?.message || "Error using item");
    }
  }
}
