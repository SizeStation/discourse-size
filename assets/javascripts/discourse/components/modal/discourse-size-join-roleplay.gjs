import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq, not, or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class DiscourseSizeJoinRoleplay extends Component {
  @service currentUser;

  @tracked selectedCharacterId = null;
  @tracked myCharacters = [];
  @tracked loading = true;
  @tracked joining = false;
  @tracked searchTerm = "";

  constructor() {
    super(...arguments);
    this.fetchCharacters();
  }

  async fetchCharacters() {
    try {
      const result = await ajax(`/size/characters`);
      const existingCharacterIds = (
        this.args.model.roleplay?.members || []
      ).map((m) => m.character_id);
      this.myCharacters = result.characters.filter(
        (c) => !existingCharacterIds.includes(c.id)
      );
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  get filteredCharacters() {
    if (!this.searchTerm) {
      return this.myCharacters;
    }
    const term = this.searchTerm.toLowerCase();
    return this.myCharacters.filter((c) => c.name.toLowerCase().includes(term));
  }

  @action
  selectCharacter(char) {
    this.selectedCharacterId = char.id;
  }

  @action
  async join() {
    if (!this.selectedCharacterId) {
      return;
    }
    this.joining = true;

    try {
      const result = await ajax(
        `/size/roleplays/${this.args.model.roleplay.id}/join`,
        {
          type: "POST",
          data: { character_id: this.selectedCharacterId },
        }
      );
      this.args.model.onJoin?.(result.roleplay);
      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.joining = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "discourse_size.roleplays.modals.join.title"}}
      @closeModal={{@closeModal}}
      class="discourse-size-join-roleplay-modal"
    >
      <:body>
        <div class="join-roleplay-content">
          {{#if this.loading}}
            <div class="loading-spinner"></div>
          {{else}}
            {{#if this.myCharacters.length}}
              <div class="search-box">
                <Input
                  @value={{this.searchTerm}}
                  @placeholder={{i18n
                    "discourse_size.roleplays.modals.join.search_placeholder"
                  }}
                  class="character-search-input"
                />
                {{icon "search"}}
              </div>

              <div class="characters-list">
                {{#each this.filteredCharacters as |char|}}
                  <div
                    class="character-list-item
                      {{if (eq this.selectedCharacterId char.id) 'selected'}}"
                    role="button"
                    tabindex="0"
                    {{on "click" (fn this.selectCharacter char)}}
                  >
                    <div class="char-pic">
                      {{#if char.picture}}
                        <img src={{char.picture}} alt />
                      {{else}}
                        {{icon "user"}}
                      {{/if}}
                    </div>
                    <div class="char-info">
                      <span class="char-name">{{char.name}}</span>
                    </div>
                    {{#if (eq this.selectedCharacterId char.id)}}
                      {{icon "check-circle"}}
                    {{/if}}
                  </div>
                {{else}}
                  <p class="no-results">{{i18n
                      "discourse_size.roleplays.no_characters"
                    }}</p>
                {{/each}}
              </div>
            {{else}}
              <p class="empty-notice">{{i18n
                  "discourse_size.roleplays.modals.join.no_characters"
                }}</p>
            {{/if}}
          {{/if}}
        </div>
      </:body>

      <:footer>
        {{#if this.myCharacters.length}}
          <DButton
            @action={{this.join}}
            @label="discourse_size.roleplays.modals.join.join_btn"
            @icon="user-plus"
            class="btn-primary"
            @disabled={{or this.joining (not this.selectedCharacterId)}}
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
