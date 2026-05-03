import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import I18n from "discourse-i18n";

export default class SizeLeaderboardController extends Controller {
  @tracked sort = "biggest";
  @tracked characters = [];

  get sortOptions() {
    return [
      { id: "biggest", label: I18n.t("size.leaderboard.biggest") },
      { id: "tiniest", label: I18n.t("size.leaderboard.tiniest") },
      { id: "smallest", label: I18n.t("size.leaderboard.smallest") },
    ];
  }

  @action
  async setSort(newSort) {
    this.sort = newSort;
    const result = await ajax(`/size/leaderboard?sort=${this.sort}`);
    this.characters = result.characters;
  }
}
