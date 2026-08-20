import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import DiscourseSizeCreateRoleplay from "./discourse-size-create-roleplay";

export default class DiscourseSizeRoleplaysModal extends Component {
  @service router;
  @service modal;

  @tracked roleplays = [];
  @tracked loading = true;
  @tracked searchTerm = "";

  constructor() {
    super(...arguments);
    this.fetchRoleplays();
  }

  async fetchRoleplays() {
    try {
      const result = await ajax("/size/roleplays");
      this.roleplays = result.roleplays;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  get filteredRoleplays() {
    if (!this.searchTerm) {
      return this.roleplays;
    }
    const term = this.searchTerm.toLowerCase();
    return this.roleplays.filter((rp) => rp.name.toLowerCase().includes(term));
  }

  @action
  openRoleplay(roleplay) {
    this.args.closeModal();
    this.router.transitionTo("size-roleplay", roleplay.uuid);
  }

  @action
  createRoleplay() {
    this.args.closeModal();
    this.modal.show(DiscourseSizeCreateRoleplay, {
      model: {
        onCreate: (roleplay) => {
          this.router.transitionTo("size-roleplay", roleplay.uuid);
        },
      },
    });
  }

  <template>
    <DModal
      @title={{i18n "discourse_size.roleplays.title"}}
      @closeModal={{@closeModal}}
      class="discourse-size-roleplays-modal"
    >
      <:body>
        <div class="roleplays-modal-content">
          <div class="search-box">
            <Input
              @value={{this.searchTerm}}
              @placeholder={{i18n
                "discourse_size.roleplays.search_placeholder"
              }}
              class="roleplay-search-input"
            />
            {{icon "search"}}
          </div>

          <div class="roleplays-list">
            {{#if this.loading}}
              <div class="loading-spinner"></div>
            {{else}}
              {{#each this.filteredRoleplays as |rp|}}
                <div
                  class="roleplay-modal-item"
                  role="button"
                  tabindex="0"
                  {{on "click" (fn this.openRoleplay rp)}}
                >
                  <div class="rp-pic">
                    {{#if rp.picture}}
                      <img src={{rp.picture}} alt />
                    {{else}}
                      {{icon "users"}}
                    {{/if}}
                  </div>
                  <div class="rp-info">
                    <span class="rp-name">{{rp.name}}</span>
                    <span class="rp-creator-small">
                      {{i18n
                        "discourse_size.roleplays.created_by"
                        username=rp.creator_username
                      }}
                    </span>
                    <div class="rp-meta-info">
                      <span class="rp-members">{{i18n
                          "discourse_size.roleplays.members_count"
                          count=rp.members_count
                        }}</span>
                      {{#if (eq rp.user_status "pending")}}
                        <span class="rp-status invited">{{i18n
                            "discourse_size.roleplays.you_are_invited"
                          }}</span>
                      {{/if}}
                    </div>
                  </div>
                  {{icon "chevron-right"}}
                </div>
              {{else}}
                <p class="no-results">{{i18n
                    "discourse_size.roleplays.no_roleplays"
                  }}</p>
              {{/each}}
            {{/if}}
          </div>
        </div>
      </:body>
      <:footer>
        <DButton
          @action={{this.createRoleplay}}
          @label="discourse_size.roleplays.create_roleplay"
          @icon="plus"
          class="btn-primary"
        />
      </:footer>
    </DModal>
  </template>
}
