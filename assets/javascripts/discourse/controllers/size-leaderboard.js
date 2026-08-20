import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { debounce } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class SizeLeaderboardController extends Controller {
  @tracked searchQuery = "";
  @tracked preferenceFilter = "all";
  @tracked characters = [];
  @tracked loadingMore = false;
  @tracked more = true;
  @tracked total = 0;

  get preferenceOptions() {
    return [
      { id: "all", name: i18n("discourse_size.directory.filter_all") },
      { id: "both", name: i18n("discourse_size.directory.prefers_both") },
      { id: "growing", name: i18n("discourse_size.directory.prefers_growing") },
      {
        id: "shrinking",
        name: i18n("discourse_size.directory.prefers_shrinking"),
      },
      { id: "neither", name: i18n("discourse_size.directory.prefers_neither") },
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
    const result = await ajax(
      `/size/directory?search=${query}&preference=${pref}&limit=100`
    );
    this.characters = result.characters;
    this.more = result.more;
    this.total = result.total;
  }

  @action
  loadMore() {
    if (this.loadingMore || !this.more) {
      return;
    }
    this.loadingMore = true;

    const query = encodeURIComponent(this.searchQuery);
    const pref = encodeURIComponent(this.preferenceFilter);
    const offset = this.characters.length;

    ajax(
      `/size/directory?search=${query}&preference=${pref}&limit=100&offset=${offset}`
    )
      .then((result) => {
        this.characters = [...this.characters, ...result.characters];
        this.more = result.more;
        this.total = result.total;
      })
      .finally(() => {
        this.loadingMore = false;
      });
  }
}
