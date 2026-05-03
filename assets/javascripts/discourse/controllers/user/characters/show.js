import Controller from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

import DiscourseSizeEditCharacter from "../../../components/modal/discourse-size-edit-character";

export default class UserCharactersShowController extends Controller {
  @service currentUser;
  @service modal;
  @service router;

  get isCurrentUser() {
    return this.currentUser && this.currentUser.id === this.user.id;
  }

  @action
  deleteCharacter(character) {
    if (confirm("Are you sure you want to delete this character?")) {
      ajax(`/size/characters/${character.id}`, { type: "DELETE" }).then(() => {
        this.router.transitionTo("user.characters.index");
      });
    }
  }

  @action
  updateCharacter(character) {
    this.modal.show(DiscourseSizeEditCharacter, {
      model: {
        character: Object.assign({}, character),
        isNew: false,
        onSave: (updatedChar) => {
          this.set("character", updatedChar);
        },
      },
    });
  }

  @action
  refreshCharacter() {
    ajax(`/size/characters?user_id=${this.user.id}`).then((result) => {
      const updated = result.characters.find(c => c.id.toString() === this.character.id.toString());
      if (updated) {
        this.set("character", updated);
      }
    });
  }
}
