import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DModal from "discourse/components/d-modal";
import icon from "discourse/helpers/d-icon";
import loadingSpinner from "discourse/helpers/loading-spinner";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

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
    return i18n("discourse_size.inventory.use_item_on", {
      name: this.args.model.character.name,
    });
  }

  get filteredInventory() {
    const char = this.args.model?.character;
    const isOwnCharacter = char && char.user_id === this.currentUser?.id;

    return this.inventory.filter((item) => {
      if (this.isBlocked(item)) {
        return false;
      }
      if (isOwnCharacter && item.details?.can_only_use_on_others) {
        return false;
      }
      if (!isOwnCharacter && item.details?.can_only_use_on_self) {
        return false;
      }
      return true;
    });
  }

  get blockedInventoryNames() {
    const char = this.args.model?.character;
    const isOwnCharacter = char && char.user_id === this.currentUser?.id;

    const names = this.inventory
      .filter((item) => {
        if (this.isBlocked(item)) {
          return true;
        }
        if (isOwnCharacter && item.details?.can_only_use_on_others) {
          return true;
        }
        if (!isOwnCharacter && item.details?.can_only_use_on_self) {
          return true;
        }
        return false;
      })
      .map((item) => item.details?.name || item.item_key);
    return [...new Set(names)];
  }

  get hasNoUsableItems() {
    const usable = this.filteredInventory;

    return !this.loading && this.inventory.length > 0 && usable.length === 0;
  }

  isBlocked(item) {
    const char = this.args.model.character;
    if (!char) {
      return true;
    }

    // Owner/Admin is never blocked
    if (this.currentUser?.id === char.user_id || this.currentUser?.admin) {
      return false;
    }

    const blockedKeys = char.blocked_item_keys || [];
    const itemKey = item.details.key;
    const effect = item.details.effect;

    if (blockedKeys.includes("__all__")) {
      return true;
    }
    if (blockedKeys.includes(itemKey)) {
      return true;
    }
    if (effect === "grow" && blockedKeys.includes("__all_growing__")) {
      return true;
    }
    if (effect === "shrink" && blockedKeys.includes("__all_shrinking__")) {
      return true;
    }
    if (effect === "static") {
      const currentSize = char.base_size + (char.target_offset || 0);
      const targetSize = item.details.amount;
      if (targetSize > currentSize && blockedKeys.includes("__all_growing__")) {
        return true;
      }
      if (
        targetSize < currentSize &&
        blockedKeys.includes("__all_shrinking__")
      ) {
        return true;
      }
    }

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
    const char = this.args.model.character;
    const isOwnCharacter = char && char.user_id === this.currentUser.id;

    let confirmMsg = i18n("discourse_size.inventory.use_confirm", {
      name: item.details.name,
    });

    if (item.details.self_effect && item.details.self_amount) {
      if (isOwnCharacter) {
        confirmMsg +=
          "\n\n" +
          i18n(
            "discourse_size.inventory.self_effect_skipped_own_character_warning"
          );
      } else {
        const mainChar = this.currentUser.discourseSizeMainCharacter;
        if (mainChar) {
          if (item.details.self_effect === "static") {
            confirmMsg +=
              "\n\n" +
              i18n("discourse_size.inventory.self_effect_static_warning", {
                character_name: mainChar.name,
                amount: item.details.self_amount,
              });
          } else {
            confirmMsg +=
              "\n\n" +
              i18n("discourse_size.inventory.self_effect_warning", {
                character_name: mainChar.name,
                effect: item.details.self_effect,
                amount: item.details.self_amount,
              });
          }
        } else {
          confirmMsg +=
            "\n\n" +
            i18n("discourse_size.inventory.self_effect_no_main_warning");
        }
      }
    }

    if (
      item.details.warning_text &&
      item.details.warning_text.trim().length > 0
    ) {
      confirmMsg += "\n\n" + item.details.warning_text.trim();
    }

    if (!confirm(confirmMsg)) {
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
        if (result.capped_type) {
          alert(
            i18n(
              result.capped_type === "max"
                ? "discourse_size.size_limit_max"
                : "discourse_size.size_limit_min"
            )
          );
        }
        this.args.model.onAction?.(result);
        this.args.closeModal();
      }
    } catch (e) {
      alert(e.jqXHR?.responseJSON?.message || "Error using item");
    }
  }

  <template>
    <DModal
      @title={{this.title}}
      @closeModal={{@closeModal}}
      class="discourse-size-use-item-modal"
    >
      <:body>
        {{#if this.loading}}
          <div class="loading-container">{{loadingSpinner}}</div>
        {{else}}
          {{#if this.filteredInventory}}
            <div class="size-inventory-grid">
              {{#each this.filteredInventory as |item|}}
                <div
                  class="size-inventory-card"
                  role="button"
                  {{on "click" (fn this.useItem item)}}
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
              {{/each}}
            </div>
          {{else}}
            <div class="empty-inventory-modal">
              {{#if this.hasNoUsableItems}}
                <div class="blocked-items-notice">
                  <p>{{i18n "discourse_size.inventory.all_items_blocked"}}</p>
                  <div class="blocked-items-preview">
                    <span class="label">{{i18n
                        "discourse_size.inventory.blocked_items_title"
                      }}</span>
                    <div class="blocked-item-tags">
                      {{#each this.blockedInventoryNames as |name|}}
                        <span class="blocked-item-tag">{{name}}</span>
                      {{/each}}
                    </div>
                  </div>
                </div>
              {{else}}
                <p>{{i18n "discourse_size.inventory.empty"}}</p>
              {{/if}}
            </div>
          {{/if}}
        {{/if}}
      </:body>
    </DModal>
  </template>
}
