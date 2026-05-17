import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { debounce } from "@ember/runloop";

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
        data: { q: this.searchTerm, roleplay_only: true }
      });
      this.searchResults = result.characters.filter(c => 
        !this.args.model.roleplay.members.some(m => m.character_id === c.id)
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
        data: { character_id: character.id }
      });
      this.args.model.onInvite?.();
      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.inviting = false;
    }
  }
}
