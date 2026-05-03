import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class SizeLeaderboardRoute extends DiscourseRoute {
  model(params) {
    // Default to biggest
    return ajax(`/size/leaderboard?sort=biggest`).then((result) => {
      return { characters: result.characters, sort: 'biggest' };
    });
  }

  setupController(controller, model) {
    controller.setProperties(model);
  }
}
