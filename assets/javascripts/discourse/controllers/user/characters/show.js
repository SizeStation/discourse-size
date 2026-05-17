import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default class UserCharactersShowController extends Controller {
  @action
  async refreshModel() {
    try {
      const result = await ajax(`/size/characters/${this.model.character.id}`);
      this.set("model.character", result.character);
    } catch (e) {
      console.error(e);
    }
  }
}
