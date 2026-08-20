import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { debounce } from "@ember/runloop";
import { service } from "@ember/service";
import { eq, gt } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class DiscourseSizeInviteToRoleplay extends Component {
  @service currentUser;

  @tracked searchTerm = "";
  @tracked searchResults = [];
  @tracked searching = false;
  @tracked inviting = false;

  @action
  onSearchInput(event) {
    this.searchTerm = event.target.value;
    debounce(this, this.searchCharacters, 300);
  }

  async searchCharacters() {
    if (this.searchTerm.length < 2) {
      this.searchResults = [];
      return;
    }
    this.searching = true;
    try {
      const result = await ajax("/size/characters", {
        data: { q: this.searchTerm, roleplay_only: true },
      });
      this.searchResults = result.characters.filter(
        (c) =>
          !this.args.model.roleplay.members.some((m) => m.character_id === c.id)
      );
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.searching = false;
    }
  }

  get isOwnCharacter() {
    return (char) => Number(char.user_id) === Number(this.currentUser.id);
  }

  @action
  async invite(character) {
    this.inviting = true;
    try {
      const isOwn = Number(character.user_id) === Number(this.currentUser.id);
      const url = isOwn
        ? `/size/roleplays/${this.args.model.roleplay.id}/join`
        : `/size/roleplays/${this.args.model.roleplay.id}/invite`;
      await ajax(url, {
        type: "POST",
        data: { character_id: character.id },
      });
      this.args.model.onInvite?.();
      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.inviting = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "discourse_size.roleplays.modals.invite.title"}}
      @closeModal={{@closeModal}}
      class="discourse-size-invite-to-roleplay-modal"
    >
      <:body>
        <div class="invite-roleplay-content">
          <div class="search-box">
            <Input
              @value={{this.searchTerm}}
              @placeholder={{i18n
                "discourse_size.roleplays.modals.invite.search_placeholder"
              }}
              class="character-search-input"
              {{on "input" this.onSearchInput}}
            />
            {{#if this.searching}}
              <div class="loading-spinner small"></div>
            {{else}}
              {{icon "search"}}
            {{/if}}
          </div>

          <div class="characters-list">
            {{#each this.searchResults as |char|}}
              <div class="character-list-item">
                <div class="char-pic">
                  {{#if char.picture}}
                    <img src={{char.picture}} alt />
                  {{else}}
                    {{icon "user"}}
                  {{/if}}
                </div>
                <div class="char-info">
                  <span class="char-name">{{char.name}}</span>
                  <span class="char-owner">@{{char.username}}</span>
                </div>
                <DButton
                  @action={{fn this.invite char}}
                  @label={{if
                    (eq char.user_id this.currentUser.id)
                    "discourse_size.roleplays.add"
                    "discourse_size.roleplays.invite"
                  }}
                  @icon={{if
                    (eq char.user_id this.currentUser.id)
                    "plus"
                    "envelope"
                  }}
                  class="btn-primary btn-small"
                  @disabled={{this.inviting}}
                />
              </div>
            {{else}}
              {{#if (gt this.searchTerm.length 1)}}
                <p class="no-results">{{i18n
                    "discourse_size.roleplays.no_characters"
                  }}</p>
              {{else}}
                <p class="instructions">{{i18n
                    "discourse_size.roleplays.modals.invite.instructions"
                  }}</p>
              {{/if}}
            {{/each}}
          </div>
        </div>
      </:body>
    </DModal>
  </template>
}
