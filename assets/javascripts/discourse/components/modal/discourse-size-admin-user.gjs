import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { concat, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { gt } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import formatDate from "discourse/helpers/format-date";
import loadingSpinner from "discourse/helpers/loading-spinner";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

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
  @tracked massAmount = 0;
  @tracked massDescription = "";
  @tracked isMassSaving = false;

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
      alert(i18n("discourse_size.error_generic"));
    } finally {
      this.isSaving = false;
    }
  }

  @action
  async addItem() {
    if (!this.selectedItemKey) {
      return;
    }
    try {
      await ajax(`/size/admin/users/${this.args.model.user.id}/inventory`, {
        type: "POST",
        data: { item_key: this.selectedItemKey },
      });
      this.fetchData();
    } catch (e) {
      alert(i18n("discourse_size.error_generic"));
    }
  }

  @action
  async removeItem(item) {
    if (!confirm(i18n("discourse_size.admin.remove_confirm"))) {
      return;
    }
    try {
      await ajax(
        `/size/admin/users/${this.args.model.user.id}/inventory/${item.id}`,
        { type: "DELETE" }
      );
      this.fetchData();
    } catch (e) {
      alert(i18n("discourse_size.error_generic"));
    }
  }

  @action
  async clearDailyReward() {
    if (!confirm(i18n("discourse_size.admin.clear_reward_confirm"))) {
      return;
    }
    try {
      await ajax(
        `/size/admin/users/${this.args.model.user.id}/clear_daily_reward`,
        {
          type: "POST",
        }
      );
      alert(i18n("discourse_size.admin.clear_reward_success"));
    } catch (e) {
      alert(i18n("discourse_size.error_generic"));
    }
  }

  @action
  async massAddPoints() {
    const amount = parseInt(this.massAmount, 10);
    if (!amount || amount <= 0) {
      return;
    }

    if (
      !confirm(i18n("discourse_size.admin.mass_points_add_confirm", { amount }))
    ) {
      return;
    }

    this.isMassSaving = true;
    try {
      await ajax("/size/admin/users/mass_points", {
        type: "POST",
        data: {
          amount,
          description: this.massDescription || undefined,
        },
      });
      alert(i18n("discourse_size.admin.mass_points_success", { amount }));
      this.massAmount = 0;
      this.massDescription = "";
    } catch (e) {
      alert(i18n("discourse_size.error_generic"));
    } finally {
      this.isMassSaving = false;
    }
  }

  @action
  async massRemovePoints() {
    const amount = parseInt(this.massAmount, 10);
    if (!amount || amount <= 0) {
      return;
    }

    if (
      !confirm(
        i18n("discourse_size.admin.mass_points_remove_confirm", { amount })
      )
    ) {
      return;
    }

    this.isMassSaving = true;
    try {
      await ajax("/size/admin/users/mass_points", {
        type: "POST",
        data: {
          amount: -amount,
          description: this.massDescription || undefined,
        },
      });
      alert(i18n("discourse_size.admin.mass_points_success", { amount }));
      this.massAmount = 0;
      this.massDescription = "";
    } catch (e) {
      alert(i18n("discourse_size.error_generic"));
    } finally {
      this.isMassSaving = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "discourse_size.admin.title"}}
      @closeModal={{@closeModal}}
      class="discourse-size-admin-user-modal"
    >
      <:body>
        <section class="admin-section mass-points-management">
          <h3>{{i18n "discourse_size.admin.mass_points_title"}}</h3>
          <p class="mass-points-description">{{i18n
              "discourse_size.admin.mass_points_description"
            }}</p>
          <div class="control-group">
            <label>{{i18n "discourse_size.admin.mass_points_amount"}}</label>
            <Input
              @type="number"
              @value={{this.massAmount}}
              class="points-input"
            />
          </div>
          <div class="control-group">
            <label>{{i18n "discourse_size.admin.mass_points_reason"}}</label>
            <Input
              @value={{this.massDescription}}
              placeholder="Site-wide distribution..."
            />
          </div>
          <div class="mass-points-buttons">
            <DButton
              @label="discourse_size.admin.mass_points_add"
              @action={{this.massAddPoints}}
              @disabled={{this.isMassSaving}}
              class="btn-primary"
            />
            <DButton
              @label="discourse_size.admin.mass_points_remove"
              @action={{this.massRemovePoints}}
              @disabled={{this.isMassSaving}}
              class="btn-danger"
            />
          </div>
        </section>

        <hr />

        <section class="admin-section points-management">
          <h3>{{i18n "discourse_size.admin.manage_points"}}</h3>
          <div class="control-group">
            <label>{{i18n "discourse_size.admin.current_points"}}</label>
            <Input @type="number" @value={{this.points}} class="points-input" />
          </div>
          <div class="control-group">
            <label>{{i18n "discourse_size.admin.reason"}}</label>
            <Input
              @value={{this.description}}
              placeholder="Admin manual adjustment..."
            />
          </div>
          <DButton
            @label="discourse_size.admin.save_points"
            @action={{this.savePoints}}
            @disabled={{this.isSaving}}
            class="btn-primary"
          />
        </section>

        <hr />

        <section class="admin-section inventory-management">
          <h3>{{i18n "discourse_size.admin.manage_inventory"}}</h3>
          {{#if this.loadingInventory}}
            {{loadingSpinner size="small"}}
          {{else}}
            <div class="add-item-controls">
              <ComboBox
                @content={{this.shopItems}}
                @value={{this.selectedItemKey}}
                @onChange={{fn this.updateValue "selectedItemKey"}}
                @options={{hash nameProperty="name" valueProperty="key"}}
              />
              <DButton
                @icon="plus"
                @label="discourse_size.admin.add_item"
                @action={{this.addItem}}
                class="btn-default"
              />
            </div>

            <div class="user-inventory-list">
              {{#each this.inventory as |item|}}
                <div class="admin-inventory-item">
                  <span class="item-name">{{item.details.name}}</span>
                  <span class="item-uses">({{i18n
                      "discourse_size.inventory.uses_left"
                      count=item.uses_remaining
                    }})</span>
                  <DButton
                    @icon="trash-can"
                    @action={{fn this.removeItem item}}
                    class="btn-danger btn-flat"
                  />
                </div>
              {{else}}
                <p class="empty-msg">{{i18n
                    "discourse_size.admin.no_items"
                  }}</p>
              {{/each}}
            </div>
          {{/if}}
        </section>

        <hr />
        <section class="admin-section reward-management">
          <h3>{{i18n "discourse_size.admin.daily_reward_section"}}</h3>
          <DButton
            @label="discourse_size.admin.clear_daily_reward"
            @action={{this.clearDailyReward}}
            class="btn-default"
          />
        </section>

        <hr />

        <section class="admin-section point-history">
          <h3>{{i18n "discourse_size.point_history.title"}}</h3>
          {{#if this.loadingHistory}}
            {{loadingSpinner size="small"}}
          {{else}}
            <div class="admin-point-history-list">
              {{#each this.history as |entry|}}
                <div class="history-entry">
                  <span class="date">{{formatDate entry.created_at}}</span>
                  <span
                    class="change
                      {{if (gt entry.amount 0) 'positive' 'negative'}}"
                  >
                    {{if (gt entry.amount 0) "+"}}{{entry.amount}}
                  </span>
                  <span class="source">{{i18n
                      (concat
                        "discourse_size.point_history.sources."
                        entry.source_type
                      )
                    }}</span>
                  {{#if entry.description}}
                    <span class="reason">({{entry.description}})</span>
                  {{/if}}
                </div>
              {{else}}
                <p class="empty-msg">{{i18n
                    "discourse_size.point_history.no_history"
                  }}</p>
              {{/each}}
            </div>
          {{/if}}
        </section>
      </:body>
    </DModal>
  </template>
}
