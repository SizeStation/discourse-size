import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class UserCharactersIndexRoute extends DiscourseRoute {
  model() {
    const user = this.modelFor("user");
    if (!user) {
      console.error("User model not found in characters index route");
      return { user: null, characters: [] };
    }
    return ajax(`/size/characters?user_id=${user.id}`).then((result) => {
      return {
        user,
        characters: result.characters,
        folders: result.folders || [],
      };
    });
  }

  setupController(controller, model) {
    controller.setProperties(model);
  }
}
