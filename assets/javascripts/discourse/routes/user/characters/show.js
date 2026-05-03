import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class UserCharactersShowRoute extends DiscourseRoute {
  model(params) {
    const user = this.modelFor("user");
    return ajax(`/size/characters?user_id=${user.id}`).then((result) => {
      const character = result.characters.find(c => c.id.toString() === params.character_id.toString());
      if (!character) {
        throw new Error("Character not found");
      }
      return {
        user: user,
        character: character
      };
    });
  }

  setupController(controller, model) {
    controller.setProperties(model);
  }
}
