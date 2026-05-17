import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { inject as service } from "@ember/service";

import I18n from "I18n";

export default class DiscourseSizeAdminUser extends Component {
  @service modal;
  @tracked points = 0;
  @tracked description = "";
  @tracked isSaving = false;
  @tracked inventory = [];
  @tracked history = [];
  @tracked shopItems = [];
  @tracked loadingInventory = true;
  @tracked loadingHistory = true;
  @tracked selectedItemKey = null;

  constructor() {
    super(...arguments);
    this.points = this.args.model.user.discourse_size_points || 0;
    this.fetchData();
    this.fetchHistory();
  }

  @action
  updateValue(path, value) {
    this[path] = value;
  }

  async fetchData() {
    try {
      const [invResult, shopResult] = await Promise.all([
        ajax(`/size/admin/users/${this.args.model.user.id}/inventory`),
        ajax("/size/shop"),
      ]);
      this.inventory = invResult.inventory;
      this.shopItems = shopResult.items;
      this.selectedItemKey = this.shopItems[0]?.key;
    } catch (e) {
      // Error
    } finally {
      this.loadingInventory = false;
    }
  }

  async fetchHistory() {
    try {
      const result = await ajax(
        `/size/admin/users/${this.args.model.user.id}/point_history`
      );
      this.history = result.history;
    } catch (e) {
      // Error
    } finally {
      this.loadingHistory = false;
    }
  }

  @action
  async savePoints() {
    this.isSaving = true;
    try {
      await ajax(`/size/admin/users/${this.args.model.user.id}/points`, {
        type: "PUT",
        data: {
          points: this.points,
          description: this.description,
        },
      });
      this.args.model.onSave?.();
      this.description = "";
    } catch (e) {
      alert(I18n.t("discourse_size.error_generic"));
    } finally {
      this.isSaving = false;
    }
  }

  @action
  async addItem() {
    if (!this.selectedItemKey) return;
    try {
      await ajax(`/size/admin/users/${this.args.model.user.id}/inventory`, {
        type: "POST",
        data: { item_key: this.selectedItemKey },
      });
      this.fetchData();
    } catch (e) {
      alert(I18n.t("discourse_size.error_generic"));
    }
  }

  @action
  async removeItem(item) {
    if (!confirm(I18n.t("discourse_size.admin.remove_confirm"))) return;
    try {
      await ajax(
        `/size/admin/users/${this.args.model.user.id}/inventory/${item.id}`,
        { type: "DELETE" }
      );
      this.fetchData();
    } catch (e) {
      alert(I18n.t("discourse_size.error_generic"));
    }
  }

  @action
  async clearDailyReward() {
    if (!confirm(I18n.t("discourse_size.admin.clear_reward_confirm"))) return;
    try {
      await ajax(
        `/size/admin/users/${this.args.model.user.id}/clear_daily_reward`,
        {
          type: "POST",
        }
      );
      alert(I18n.t("discourse_size.admin.clear_reward_success"));
    } catch (e) {
      alert(I18n.t("discourse_size.error_generic"));
    }
  }
}
