import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class UserCharactersIndexRoute extends DiscourseRoute {
  model() {
    const user = this.modelFor("user");
    if (!user) {
      console.error("User model not found in characters index route");
      return { user: null, characters: [] };
    }
    return ajax(`/size/characters?user_id=${user.id}`).then((result) => {
      return {
        user: user,
        characters: result.characters,
      };
    });
  }

  setupController(controller, model) {
    controller.setProperties(model);
  }
}
