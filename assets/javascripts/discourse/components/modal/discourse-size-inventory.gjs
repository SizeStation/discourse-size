import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import icon from "discourse/helpers/d-icon";
import loadingSpinner from "discourse/helpers/loading-spinner";
import { ajax } from "discourse/lib/ajax";
import I18n, { i18n } from "discourse-i18n";

export default class DiscourseSizeInventory extends Component {
  @service currentUser;

  @tracked inventory = [];
  @tracked loading = true;

  constructor() {
    super(...arguments);
    this.fetchInventory();
  }

  async fetchInventory() {
    try {
      const userId = this.args.model.giftingMode
        ? this.currentUser.id
        : this.args.model.user.id;

      const result = await ajax("/size/inventory", {
        data: { user_id: userId },
      });
      this.inventory = result.inventory;
    } catch (e) {
      // Error
    } finally {
      this.loading = false;
    }
  }

  useItem(item) {
    if (this.args.model.characterId) {
      this.args.model.onSelect?.(item);
    }
  }

  get isClickable() {
    return !!this.args.model.onSelect;
  }

  @action
  selectItem(item) {
    if (this.isClickable) {
      this.args.model.onSelect?.(item);
    }
  }

  <template>
    <DModal
      @title={{i18n "discourse_size.inventory.my_inventory"}}
      @closeModal={{@closeModal}}
      class="discourse-size-inventory-modal"
    >
      <:body>
        {{#if this.loading}}
          <div class="loading-container">
            {{loadingSpinner size="small"}}
          </div>
        {{else}}
          <div class="size-inventory-grid">
            {{#each this.inventory as |item|}}
              <div
                class="size-inventory-card
                  {{if (eq @model.selectedItemId item.id) 'selected'}}
                  {{unless this.isClickable 'no-click'}}"
                role="button"
                {{on "click" (fn this.selectItem item)}}
              >
                <div class="item-image">
                  {{#if item.details.picture}}
                    <img
                      src={{item.details.picture}}
                      alt={{item.details.name}}
                    />
                  {{else}}
                    {{icon
                      (if
                        (eq item.details.effect "grow")
                        "angle-double-up"
                        (if
                          (eq item.details.effect "shrink")
                          "angle-double-down"
                          "sync"
                        )
                      )
                    }}
                  {{/if}}
                </div>
                <div class="item-details">
                  <div class="item-main-info">
                    <span class="item-name">{{item.details.name}}</span>
                    <span class="item-uses">
                      {{#if (eq item.uses_remaining 999999)}}
                        {{i18n "discourse_size.inventory.infinite_uses"}}
                      {{else}}
                        {{i18n
                          "discourse_size.inventory.uses_out_of"
                          count=item.uses_remaining
                          total=item.details.uses
                        }}
                      {{/if}}
                    </span>
                  </div>
                  {{#if item.details.description}}
                    <span
                      class="item-description"
                    >{{item.details.description}}</span>
                  {{/if}}
                </div>
              </div>
            {{else}}
              <div class="empty-inventory">
                <div>{{i18n "discourse_size.inventory.empty"}}</div>
                <DButton
                  @href="/size/shop"
                  @label="discourse_size.shop.go_to_shop"
                  class="btn-primary"
                  @action={{@closeModal}}
                />
              </div>
            {{/each}}
          </div>
        {{/if}}
      </:body>
    </DModal>
  </template>
}
