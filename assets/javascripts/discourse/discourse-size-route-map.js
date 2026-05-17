export default function () {
  this.route("size-leaderboard", { path: "/size/directory" });
  this.route("size-shop", { path: "/size/shop" });
  this.route("size-roleplays", { path: "/size/roleplays" });
  this.route("size-roleplay", { path: "/size/roleplays/:id" });
}
