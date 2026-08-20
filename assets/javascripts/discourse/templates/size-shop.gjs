import { fn } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import { eq, gt, or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import DiscourseSizeReorderableList from "../components/discourse-size-reorderable-list";

export default RouteTemplate(
  <template>
    <div class="size-shop-container">
      <div class="shop-header">
        <div class="shop-title">
          <h1>{{@controller.shopName}}</h1>
        </div>
        <div class="shop-meta">
          {{#if @controller.canManageShop}}
            <DButton
              @icon="plus"
              @label="discourse_size.shop.add_item"
              @action={{@controller.addShopItem}}
              class="btn-default add-item-btn"
            />
          {{/if}}
          <DButton
            @label="discourse_size.inventory.my_inventory"
            @icon="inbox"
            @action={{@controller.showInventory}}
            class="btn-default"
          />
          <DButton @action={{@controller.showPointHistory}} class="btn-default">
            <span>Balance:
              {{@controller.currentPoints}}
              {{i18n "discourse_size.admin_points"}}</span>
          </DButton>
          <DButton
            @label={{if
              (eq
                @controller.currentUser.discourse_size_daily_reward_status
                "available"
              )
              "discourse_size.shop.claim_reward"
              "discourse_size.shop.earn_coins"
            }}
            @action={{@controller.showQuests}}
            class="btn-default claim-reward-btn"
          />
        </div>
      </div>

      <div class="shop-grid-wrapper">
        {{#if @controller.canManageShop}}
          <DiscourseSizeReorderableList
            @enabled={{true}}
            @onReorder={{@controller.reorderItems}}
            @handle=".drag-handle"
            class="shop-grid"
          >
            {{#each @controller.items as |item|}}
              <div
                class="shop-item-card
                  {{if (gt item.price @controller.currentPoints) 'expensive'}}"
              >
                <div class="item-header">
                  {{#if item.picture}}
                    <div class="item-image">
                      <img src={{item.picture}} alt={{item.name}} />
                    </div>
                  {{/if}}
                  <div class="drag-handle">
                    {{icon "grip-lines"}}
                  </div>
                </div>
                <div class="item-info">
                  <h2 class="item-name">{{item.name}}</h2>
                  <div class="item-stats">
                    <span
                      class="stat stock {{if (eq item.stock 0) 'out-of-stock'}}"
                    >
                      {{i18n "discourse_size.shop.stats.stock"}}:
                      {{if
                        (eq item.stock -1)
                        (i18n "discourse_size.shop.stats.infinite")
                        item.stock
                      }}
                    </span>
                    {{#unless item.enabled}}
                      <span class="stat disabled-label">{{i18n
                          "discourse_size.shop.stats.disabled"
                        }}</span>
                    {{/unless}}
                  </div>
                  <p class="item-description">{{item.description}}</p>
                </div>
                <div class="item-footer">
                  <span class="item-price">{{item.price}} Coins</span>
                  <div class="actions">
                    <DButton
                      @icon="pencil"
                      @action={{fn @controller.editShopItem item}}
                      class="btn-default edit-btn"
                    />
                    {{#if (eq item.stock 0)}}
                      <span class="out-of-stock-label">{{i18n
                          "discourse_size.shop.out_of_stock"
                        }}</span>
                    {{else}}
                      <DButton
                        @label={{if
                          (gt item.price @controller.currentPoints)
                          "discourse_size.shop.too_expensive"
                          "discourse_size.shop.purchase"
                        }}
                        @action={{fn @controller.purchaseItem item}}
                        @disabled={{or
                          (gt item.price @controller.currentPoints)
                          (eq @controller.purchasing item.key)
                        }}
                        class={{if
                          (gt item.price @controller.currentPoints)
                          "btn-danger purchase-btn"
                          "btn-primary purchase-btn"
                        }}
                      />
                    {{/if}}
                  </div>
                </div>
              </div>
            {{/each}}
          </DiscourseSizeReorderableList>
        {{else}}
          <div class="shop-grid">
            {{#each @controller.items as |item|}}
              <div
                class="shop-item-card
                  {{if (gt item.price @controller.currentPoints) 'expensive'}}"
              >
                {{#if item.picture}}
                  <div class="item-image">
                    <img src={{item.picture}} alt={{item.name}} />
                  </div>
                {{/if}}
                <div class="item-info">
                  <h2 class="item-name">{{item.name}}</h2>
                  <div class="item-stats">
                    <span
                      class="stat stock {{if (eq item.stock 0) 'out-of-stock'}}"
                    >
                      {{i18n "discourse_size.shop.stats.stock"}}:
                      {{if
                        (eq item.stock -1)
                        (i18n "discourse_size.shop.stats.infinite")
                        item.stock
                      }}
                    </span>
                    {{#unless item.enabled}}
                      <span class="stat disabled-label">{{i18n
                          "discourse_size.shop.stats.disabled"
                        }}</span>
                    {{/unless}}
                  </div>
                  <p class="item-description">{{item.description}}</p>
                </div>
                <div class="item-footer">
                  <span class="item-price">{{item.price}} Coins</span>
                  <div class="actions">
                    {{#if (eq item.stock 0)}}
                      <span class="out-of-stock-label">{{i18n
                          "discourse_size.shop.out_of_stock"
                        }}</span>
                    {{else}}
                      <DButton
                        @label={{if
                          (gt item.price @controller.currentPoints)
                          "discourse_size.shop.too_expensive"
                          "discourse_size.shop.purchase"
                        }}
                        @action={{fn @controller.purchaseItem item}}
                        @disabled={{or
                          (gt item.price @controller.currentPoints)
                          (eq @controller.purchasing item.key)
                        }}
                        class={{if
                          (gt item.price @controller.currentPoints)
                          "btn-danger purchase-btn"
                          "btn-primary purchase-btn"
                        }}
                      />
                    {{/if}}
                  </div>
                </div>
              </div>
            {{/each}}
          </div>
        {{/if}}
      </div>
    </div>
  </template>
);
