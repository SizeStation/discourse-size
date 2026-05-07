import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class UserCharactersShowRoute extends DiscourseRoute {
  model(params) {
    const user = this.modelFor("user");
    return ajax(`/size/characters/${params.character_id}`).then((result) => {
      return {
        user: user,
        character: result.character,
      };
    });
  }

  setupController(controller, model) {
    controller.setProperties(model);
    controller.set("isCurrentUser", this.currentUser && this.currentUser.id === model.user?.id);
  }
}
