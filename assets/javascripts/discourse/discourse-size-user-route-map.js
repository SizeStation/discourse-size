export default {
  resource: "user",
  path: "users/:username",
  map() {
    this.route("characters", function () {
      this.route("show", { path: "/:character_id" });
    });
  },
};
