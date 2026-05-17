import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { debounce } from "@ember/runloop";
import I18n from "discourse-i18n";

export default class SizeLeaderboardController extends Controller {
  @tracked searchQuery = "";
  @tracked preferenceFilter = "all";
  @tracked characters = [];

  get preferenceOptions() {
    return [
      { id: "all", name: I18n.t("discourse_size.directory.filter_all") },
      { id: "both", name: I18n.t("discourse_size.directory.prefers_both") },
      { id: "growing", name: I18n.t("discourse_size.directory.prefers_growing") },
      { id: "shrinking", name: I18n.t("discourse_size.directory.prefers_shrinking") },
      { id: "neither", name: I18n.t("discourse_size.directory.prefers_neither") },
    ];
  }

  @action
  updateSearch(event) {
    this.searchQuery = event.target.value;
    debounce(this, this.performSearch, 300);
  }

  @action
  setPreferenceFilter(value) {
    this.preferenceFilter = value;
    this.performSearch();
  }

  async performSearch() {
    const query = encodeURIComponent(this.searchQuery);
    const pref = encodeURIComponent(this.preferenceFilter);
    const result = await ajax(`/size/leaderboard?search=${query}&preference=${pref}`);
    this.characters = result.characters;
  }
}
