import { inject as service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class SizeShopRoute extends DiscourseRoute {
  @service currentUser;

  async model() {
    return await ajax("/size/shop");
  }

  setupController(controller, model) {
    controller.setProperties({
      items: model.items,
      shopName: model.shop_name,
      currentPoints: model.current_points,
    });
  }
}
