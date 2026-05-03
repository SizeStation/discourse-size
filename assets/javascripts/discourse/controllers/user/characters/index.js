import Controller from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

import DiscourseSizeEditCharacter from "../../../components/modal/discourse-size-edit-character";
import DiscourseSizeAdminPoints from "../../../components/modal/discourse-size-admin-points";

export default class UserCharactersIndexController extends Controller {
  @service currentUser;
  @service modal;
  @service siteSettings;

  get isCurrentUser() {
    return this.currentUser && this.currentUser.id === this.user.id;
  }

  @action
  adminEditPoints() {
    this.modal.show(DiscourseSizeAdminPoints, {
      model: {
        user: this.user,
        points: this.user.discourse_size_points,
        onSave: (newPoints) => {
          this.set("user.discourse_size_points", parseInt(newPoints, 10));
        }
      }
    });
  }

  @action
  createNewCharacter() {
    this.modal.show(DiscourseSizeEditCharacter, {
      model: {
        character: {},
        isNew: true,
        onSave: (newChar) => {
          this.set("characters", [...this.characters, newChar]);
        },
      },
    });
  }

  @action
  deleteCharacter(character) {
    if (confirm("Are you sure you want to delete this character?")) {
      ajax(`/size/characters/${character.id}`, { type: "DELETE" }).then(() => {
        this.set(
          "characters",
          this.characters.filter((c) => c.id !== character.id)
        );
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
          const index = this.characters.findIndex(
            (c) => c.id === updatedChar.id
          );
          if (index !== -1) {
            const newChars = [...this.characters];
            newChars[index] = updatedChar;
            this.set("characters", newChars);
          }
        },
      },
    });
  }

  @action
  refreshCharacters() {
    ajax(`/size/characters?user_id=${this.user.id}`).then((result) => {
      this.set("characters", result.characters);
    });
  }
}
