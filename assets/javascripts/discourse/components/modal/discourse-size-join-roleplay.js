import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";

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
      const existingCharacterIds = (this.args.model.roleplay?.members || []).map(m => m.character_id);
      this.myCharacters = result.characters.filter(c => 
        !existingCharacterIds.includes(c.id)
      );
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  get filteredCharacters() {
    if (!this.searchTerm) return this.myCharacters;
    const term = this.searchTerm.toLowerCase();
    return this.myCharacters.filter(c => c.name.toLowerCase().includes(term));
  }

  @action
  selectCharacter(char) {
    this.selectedCharacterId = char.id;
  }

  @action
  async join() {
    if (!this.selectedCharacterId) return;
    this.joining = true;

    try {
      const result = await ajax(`/size/roleplays/${this.args.model.roleplay.id}/join`, {
        type: "POST",
        data: { character_id: this.selectedCharacterId },
      });
      this.args.model.onJoin?.(result.roleplay);
      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.joining = false;
    }
  }
}
