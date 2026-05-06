import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { tracked } from "@glimmer/tracking";
import I18n from "I18n";

export default class DiscourseSizePointHistory extends Component {
  @service currentUser;
  @service modal;
  @tracked history = [];
  @tracked loading = true;
  @tracked currentPoints = 0;

  constructor() {
    super(...arguments);
    this.fetchHistory();
  }

  async fetchHistory() {
    try {
      const result = await ajax("/size/point_history", {
        data: { user_id: this.args.model.user.id },
      });
      this.history = result.history;
      this.currentPoints = result.current_points;
    } catch (e) {
      // Error
    } finally {
      this.loading = false;
    }
  }

  @action
  async deleteEntry(entry) {
    if (!confirm(I18n.t("discourse_size.point_history.confirm_delete"))) {
      return;
    }

    try {
      await ajax(`/size/point_history/${entry.id}`, { type: "DELETE" });
      this.fetchHistory();
      this.args.model.onSave?.();
    } catch (e) {
      alert("Error deleting entry");
    }
  }

  @action
  formatDate(date) {
    return moment(date).format("YYYY-MM-DD HH:mm");
  }

  @action
  sourceLabel(source) {
    return I18n.t(`discourse_size.point_history.sources.${source}`, {
      defaultValue: source,
    });
  }
}
