import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class SizeRoleplayRoute extends DiscourseRoute {
  model(params) {
    return ajax(`/size/roleplays/${params.id}`);
  }

  setupController(controller, model) {
    controller.set("roleplay", model.roleplay);
  }

  @action
  reloadModel() {
    this.refresh();
  }
}
