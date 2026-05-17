import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class SizeLeaderboardRoute extends DiscourseRoute {
  model(params) {
    return ajax(`/size/directory?sort=biggest&limit=100`).then((result) => {
      return { characters: result.characters, sort: "biggest", total: result.total, more: result.more };
    });
  }

  setupController(controller, model) {
    controller.setProperties(model);
  }
}
