import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class SizeRoleplaysRoute extends DiscourseRoute {
  model() {
    return ajax("/size/roleplays");
  }

  setupController(controller, model) {
    controller.set("roleplays", model.roleplays);
  }
}
