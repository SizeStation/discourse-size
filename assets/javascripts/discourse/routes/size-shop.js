import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

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
      canManageShop: model.can_manage_shop,
    });
  }
}
