import Controller from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { tracked } from "@glimmer/tracking";
import DiscourseSizeInventory from "../components/modal/discourse-size-inventory";
import DiscourseSizePointHistory from "../components/modal/discourse-size-point-history";
import I18n from "I18n";

import DiscourseSizeEditShopItem from "../components/modal/discourse-size-edit-shop-item";

export default class SizeShopController extends Controller {
  @service currentUser;
  @service modal;
  @service router;
  @tracked items = [];
  @tracked shopName = "Size Shop";
  @tracked currentPoints = 0;
  @tracked purchasing = null;

  @action
  addShopItem() {
    this.modal.show(DiscourseSizeEditShopItem, {
      model: {
        onSave: () => {
          this.router.refresh();
        },
      },
    });
  }

  @action
  addSectionHeader() {
    this.modal.show(DiscourseSizeEditShopItem, {
      model: {
        item: {
          item_type: "header",
          name: "New Section",
          key: "section-" + Date.now(),
        },
        onSave: () => {
          this.router.refresh();
        },
      },
    });
  }

  @action
  editShopItem(item) {
    this.modal.show(DiscourseSizeEditShopItem, {
      model: {
        item,
        onSave: () => {
          this.router.refresh();
        },
      },
    });
  }

  @action
  async purchaseItem(item) {
    if (this.currentPoints < item.price) {
      alert(I18n.t("discourse_size.shop.insufficient_points"));
      return;
    }

    if (
      !confirm(
        I18n.t("discourse_size.shop.purchase_confirm", {
          name: item.name,
          price: item.price,
        })
      )
    ) {
      return;
    }

    this.purchasing = item.key;
    try {
      const result = await ajax("/size/shop/purchase", {
        type: "POST",
        data: { item_key: item.key },
      });

      if (result.success) {
        this.currentPoints = result.current_points;
      }
    } catch (e) {
      alert(e.jqXHR?.responseJSON?.message || "Error purchasing item");
    } finally {
      this.purchasing = null;
    }
  }

  @action
  async claimDailyReward() {
    try {
      const result = await ajax("/size/shop/claim_reward", {
        type: "POST",
      });

      if (result.success) {
        this.currentPoints = result.current_points;
        this.currentUser.set("discourse_size_can_claim_daily_reward", false);
        alert(
          I18n.t("discourse_size.shop.reward_claimed", {
            amount: result.amount,
          })
        );
      }
    } catch (e) {
      alert(e.jqXHR?.responseJSON?.message || "Error claiming reward");
    }
  }

  @action
  showInventory() {
    this.modal.show(DiscourseSizeInventory, {
      model: {
        user: this.currentUser,
        onSave: () => {
          // Maybe refresh points
        },
      },
    });
  }

  @action
  showPointHistory() {
    this.modal.show(DiscourseSizePointHistory, {
      model: {
        user: this.currentUser,
      },
    });
  }

  @action
  async reorderItems(evt) {
    const { oldIndex, newIndex } = evt;
    if (oldIndex === newIndex) {
      return;
    }

    const newItems = [...this.items];
    const [movedItem] = newItems.splice(oldIndex, 1);
    newItems.splice(newIndex, 0, movedItem);

    this.items = newItems;
    const ids = newItems.map((i) => i.id);

    try {
      await ajax("/size/admin/shop_items/reorder", {
        type: "POST",
        data: { ids },
      });
    } catch (e) {
      // Failed to save order
    }
  }
}
