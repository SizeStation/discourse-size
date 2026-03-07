export default function() {
  this.route("user", { path: "/u/:username" }, function() {
    this.route("size", { path: "/size" });
  });
}
