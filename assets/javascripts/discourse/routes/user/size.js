import DiscourseRoute from "discourse/routes/discourse";

export default class UserSizeRoute extends DiscourseRoute {
  model() {
    return this.modelFor("user");
  }
}
