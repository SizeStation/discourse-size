import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { gt, lt } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import loadingSpinner from "discourse/helpers/loading-spinner";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

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
    if (!confirm(i18n("discourse_size.point_history.confirm_delete"))) {
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
    return i18n(`discourse_size.point_history.sources.${source}`, {
      defaultValue: source,
    });
  }

  <template>
    <DModal
      @title={{i18n "discourse_size.point_history.title"}}
      @closeModal={{@closeModal}}
      class="discourse-size-point-history-modal"
    >
      <:body>
        <div class="history-summary">
          <span class="current-balance">
            {{i18n
              "discourse_size.point_history.current_balance"
              points=this.currentPoints
            }}
          </span>
        </div>

        {{#if this.loading}}
          <div class="loading-container">
            {{loadingSpinner size="small"}}
          </div>
        {{else}}
          <div class="history-list-container">
            {{#if this.history}}
              <table class="table history-table">
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Source</th>
                    <th>Amount</th>
                    <th>Description</th>
                    {{#if this.currentUser.admin}}
                      <th></th>
                    {{/if}}
                  </tr>
                </thead>
                <tbody>
                  {{#each this.history as |entry|}}
                    <tr
                      class="history-entry
                        {{if (lt entry.amount 0) 'negative' 'positive'}}"
                    >
                      <td class="date">{{this.formatDate entry.created_at}}</td>
                      <td class="source">{{this.sourceLabel
                          entry.source_type
                        }}</td>
                      <td class="amount">
                        {{#if (gt entry.amount 0)}}+{{/if}}{{entry.amount}}
                      </td>
                      <td class="description">{{entry.description}}</td>
                      {{#if this.currentUser.admin}}
                        <td class="actions">
                          <DButton
                            @icon="trash-can"
                            @action={{fn this.deleteEntry entry}}
                            class="btn-danger btn-flat"
                            @title="Delete and revert points"
                          />
                        </td>
                      {{/if}}
                    </tr>
                  {{/each}}
                </tbody>
              </table>
            {{else}}
              <div class="no-history">
                {{i18n "discourse_size.point_history.no_history"}}
              </div>
            {{/if}}
          </div>
        {{/if}}
      </:body>
    </DModal>
  </template>
}
