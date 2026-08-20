import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, notifyPropertyChange } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { and, eq, not, notEq, or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import avatar from "discourse/helpers/avatar";
import formatDate from "discourse/helpers/format-date";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import abs from "../../helpers/abs";
import formatSize0 from "../../helpers/format-size";
import { formatSize } from "../../lib/size-formatter";

const SERIES_COLORS = [
  "#e74c3c",
  "#2ecc71",
  "#f39c12",
  "#9b59b6",
  "#1abc9c",
  "#e67e22",
  "#3498db",
  "#e91e63",
  "#00bcd4",
  "#8bc34a",
];

export default class DiscourseSizeGrowthGraph extends Component {
  @service currentUser;

  @service siteSettings;

  @tracked hoveredPoint = null;
  @tracked _character = null;

  get character() {
    return this._character || this.args?.model?.character;
  }

  set character(character) {
    this._character = character;
  }

  get preferredSystem() {
    return (
      this.currentUser?.discourse_size_settings?.measurement_system ||
      this.character?.measurement_system ||
      "imperial"
    );
  }

  get actions() {
    return (this.character?.actions || []).filter((a) => !a.parent_action_id);
  }

  get canManageCharacter() {
    return (
      this.currentUser?.admin ||
      this.character?.user_id === this.currentUser?.id
    );
  }

  get newestFirstActions() {
    return this.actions;
  }

  get canSeeBlockedStatus() {
    if (!this.currentUser) {
      return false;
    }
    const char = this.character;
    return this.currentUser.id === char?.user_id || this.currentUser.admin;
  }

  get series() {
    const char = this.character;
    if (!char || !char.actions) {
      return [];
    }

    const allActions = char.actions || [];
    const result = [];

    // --- Size series ---
    const sizeActions = allActions
      .filter(
        (a) =>
          ["grow", "shrink", "set_size"].includes(a.action_type) &&
          a.start_time &&
          a.end_time
      )
      .sort((a, b) => new Date(a.start_time) - new Date(b.start_time));

    const sizePoints = [];
    sizeActions.forEach((a, i) => {
      if (i === 0) {
        sizePoints.push({
          date: new Date(a.start_time),
          value:
            (parseFloat(char.base_size) || 0) +
            (parseFloat(a.start_offset) || 0),
        });
      }
      sizePoints.push({
        date: new Date(a.end_time),
        value:
          (parseFloat(char.base_size) || 0) + (parseFloat(a.end_offset) || 0),
        action: a,
      });
    });

    if (sizePoints.length > 0) {
      result.push({
        name: "Size",
        key: "__size__",
        points: sizePoints,
        color: null,
      });
    }

    // --- Property series ---
    const propNames = [
      ...new Set(
        allActions
          .filter((a) => a.action_type === "property_change")
          .map((a) => a.item_key)
      ),
    ];

    propNames.forEach((name, idx) => {
      const propActions = allActions
        .filter(
          (a) =>
            a.action_type === "property_change" &&
            a.item_key === name &&
            a.start_time &&
            a.end_time
        )
        .sort((a, b) => new Date(a.start_time) - new Date(b.start_time));

      if (propActions.length === 0) {
        return;
      }

      const points = [];
      points.push({
        date: new Date(propActions[0].start_time),
        value: parseFloat(propActions[0].start_offset || 0),
      });
      propActions.forEach((a) => {
        points.push({
          date: new Date(a.end_time),
          value: parseFloat(a.end_offset || 0),
          action: a,
        });
      });

      result.push({
        name,
        key: name,
        points,
        color: SERIES_COLORS[idx % SERIES_COLORS.length],
      });
    });

    return result;
  }

  get graphData() {
    const allSeries = this.series;
    if (allSeries.length === 0 || allSeries.every((s) => s.points.length < 2)) {
      return null;
    }

    const width = 800;
    const height = 400;
    const paddingX = 80;
    const paddingY = 60;

    // Collect all values and dates across all series
    let allValues = [];
    let allDates = [];
    allSeries.forEach((s) => {
      s.points.forEach((p) => {
        allValues.push(p.value);
        allDates.push(p.date);
      });
    });

    const minVal = Math.min(...allValues);
    const maxVal = Math.max(...allValues);
    const valRange = maxVal - minVal || 1;
    const earliest = new Date(Math.min(...allDates));
    const latest = new Date(Math.max(...allDates));
    const timeRange = latest.getTime() - earliest.getTime() || 1;

    const seriesPaths = [];
    const flatPoints = [];

    allSeries.forEach((s) => {
      const pts = s.points.map((p, i) => {
        const x =
          paddingX +
          ((p.date.getTime() - earliest.getTime()) / timeRange) *
            (width - 2 * paddingX);
        const y =
          height -
          paddingY -
          ((p.value - minVal) / valRange) * (height - 2 * paddingY);
        const tooltipWidth = 180;
        const tooltipHeight = p.label ? 68 : 54;
        const tooltipX = Math.min(
          Math.max(x - tooltipWidth / 2, 10),
          width - tooltipWidth - 10
        );
        const tooltipY =
          y - tooltipHeight - 12 < 10 ? y + 15 : y - tooltipHeight - 12;

        return {
          x,
          y,
          value: p.value,
          date: p.date,
          action: p.action,
          label: p.label,
          seriesKey: s.key,
          seriesName: s.name,
          tooltipX,
          tooltipY,
          tooltipWidth,
          tooltipHeight,
          tooltipNameX: tooltipX + 12,
          tooltipNameY: tooltipY + 22,
          tooltipLabelY: tooltipY + 38,
          tooltipSizeY: p.label ? tooltipY + 54 : tooltipY + 42,
          formattedSize: formatSize(p.value, this.preferredSystem),
        };
      });

      let path = "";
      for (let i = 0; i < pts.length; i++) {
        path +=
          i === 0 ? `M ${pts[i].x} ${pts[i].y}` : ` L ${pts[i].x} ${pts[i].y}`;
      }

      seriesPaths.push({
        key: s.key,
        name: s.name,
        path,
        color: s.color,
        points: pts,
      });

      pts.forEach((p) => flatPoints.push(p));
    });

    flatPoints.sort((a, b) => b.date - a.date);

    return {
      seriesPaths,
      points: flatPoints,
      width,
      height,
      minVal,
      maxVal,
    };
  }

  get formattedMinVal() {
    return formatSize(this.graphData?.minVal || 0, this.preferredSystem);
  }

  get formattedMaxVal() {
    return formatSize(this.graphData?.maxVal || 0, this.preferredSystem);
  }

  get topContributors() {
    const actions = this.actions;
    const byUser = {};

    actions.forEach((action) => {
      if (
        action.action_type === "reset" ||
        action.action_type === "boost_speed" ||
        !action.size_change
      ) {
        return;
      }
      const userId = action.user_id || action.user?.id;
      if (!userId) {
        return;
      }
      if (!byUser[userId]) {
        byUser[userId] = {
          user: action.user,
          totalImpactCm: 0,
          totalPoints: 0,
        };
      }
      byUser[userId].totalImpactCm += parseFloat(action.size_change || 0);
      byUser[userId].totalPoints += parseFloat(action.points_spent || 0);
    });

    return Object.values(byUser)
      .sort((a, b) => b.totalImpactCm - a.totalImpactCm)
      .slice(0, 10)
      .map((entry) => ({
        ...entry,
        isBlocked:
          entry.user &&
          Number(entry.user.id) !== Number(this.character.user_id) &&
          this.character.blocked_user_ids
            ?.map((id) => Number(id))
            .includes(Number(entry.user.id)),
        formattedSize: formatSize(entry.totalImpactCm, this.preferredSystem),
      }));
  }

  @action
  setHoveredPoint(point) {
    this.hoveredPoint = point;
  }

  @action
  async deleteAction(actionItem) {
    if (actionItem.parent_action_id && !this.currentUser.admin) {
      alert(i18n("discourse_size.activity.self_effect_delete_error"));
      return;
    }

    const key =
      actionItem.item_key || actionItem.points_spent > 0
        ? "discourse_size.delete_action_with_return_confirm"
        : "discourse_size.delete_action_confirm";

    if (!confirm(i18n(key))) {
      return;
    }

    try {
      const result = await ajax(`/size/actions/${actionItem.id}`, {
        type: "DELETE",
      });
      if (result.character) {
        this.character = result.character;
        this.args.model.onActionDeleted?.(result.character);
      } else {
        this.character.actions = this.character.actions.filter(
          (action) => action.id !== actionItem.id
        );
      }

      notifyPropertyChange(this, "character");
      notifyPropertyChange(this, "series");
      notifyPropertyChange(this, "graphData");
      notifyPropertyChange(this, "actions");
      notifyPropertyChange(this, "newestFirstActions");
      notifyPropertyChange(this, "topContributors");
    } catch (e) {
      alert("Error deleting action");
    }
  }

  @action
  async blockUser(user) {
    if (
      !confirm(
        i18n("discourse_size.blocking.confirm_block_user", {
          username: user.username,
        })
      )
    ) {
      return;
    }

    try {
      await ajax(`/size/characters/${this.character.id}/block_user`, {
        type: "POST",
        data: { user_id: user.id },
      });
      this.character.blocked_user_ids = [
        ...(this.character.blocked_user_ids || []),
        user.id,
      ];
      notifyPropertyChange(this, "topContributors");
    } catch (e) {
      alert("Error blocking user");
    }
  }

  @action
  async unblockUser(user) {
    if (
      !confirm(
        i18n("discourse_size.blocking.confirm_unblock_user", {
          username: user.username,
        })
      )
    ) {
      return;
    }

    try {
      await ajax(`/size/characters/${this.character.id}/unblock_user`, {
        type: "POST",
        data: { user_id: user.id },
      });
      this.character.blocked_user_ids = (
        this.character.blocked_user_ids || []
      ).filter((id) => id !== user.id);
      notifyPropertyChange(this, "topContributors");
    } catch (e) {
      alert("Error unblocking user");
    }
  }

  <template>
    <DModal
      @title={{i18n "discourse_size.size_history"}}
      @closeModal={{@closeModal}}
      class="discourse-size-growth-graph-modal"
    >
      <:body>
        <div class="growth-graph-container">
          {{#if this.graphData}}
            <div class="svg-wrapper">
              <svg
                viewBox="0 0 {{this.graphData.width}} {{this.graphData.height}}"
                class="growth-svg"
              >
                {{! Grid lines }}
                <line
                  x1="60"
                  y1="60"
                  x2="60"
                  y2="340"
                  stroke="var(--primary-low)"
                  stroke-dasharray="4"
                />
                <line
                  x1="60"
                  y1="340"
                  x2="740"
                  y2="340"
                  stroke="var(--primary-low)"
                  stroke-dasharray="4"
                />

                {{! Labels }}
                <text
                  x="55"
                  y="65"
                  text-anchor="end"
                  class="axis-label"
                >{{this.formattedMaxVal}}</text>
                <text
                  x="55"
                  y="345"
                  text-anchor="end"
                  class="axis-label"
                >{{this.formattedMinVal}}</text>

                {{! Series paths }}
                {{#each this.graphData.seriesPaths as |sp|}}
                  <path
                    d={{sp.path}}
                    fill="none"
                    stroke={{if sp.color sp.color "var(--tertiary)"}}
                    stroke-width="3"
                    stroke-linejoin="round"
                    stroke-linecap="round"
                  />
                  {{! Points for this series }}
                  {{#each sp.points as |point|}}
                    <circle
                      cx={{point.x}}
                      cy={{point.y}}
                      r="5"
                      fill={{if sp.color sp.color "var(--tertiary)"}}
                      class="graph-point"
                      {{on "mouseenter" (fn this.setHoveredPoint point)}}
                      {{on "mouseleave" (fn this.setHoveredPoint null)}}
                    />
                  {{/each}}
                {{/each}}

                {{! Tooltip }}
                {{#if this.hoveredPoint}}
                  <g class="graph-tooltip">
                    <rect
                      x={{this.hoveredPoint.tooltipX}}
                      y={{this.hoveredPoint.tooltipY}}
                      width={{this.hoveredPoint.tooltipWidth}}
                      height={{this.hoveredPoint.tooltipHeight}}
                      rx="8"
                      fill="var(--secondary)"
                      stroke="var(--tertiary)"
                      stroke-width="1.5"
                    />
                    <text
                      x={{this.hoveredPoint.tooltipNameX}}
                      y={{this.hoveredPoint.tooltipNameY}}
                      class="tooltip-name"
                    >
                      {{this.hoveredPoint.seriesName}}
                      {{#if this.hoveredPoint.action}}
                        —
                        {{this.hoveredPoint.action.user.username}}
                      {{/if}}
                    </text>
                    {{#if this.hoveredPoint.label}}
                      <text
                        x={{this.hoveredPoint.tooltipNameX}}
                        y={{this.hoveredPoint.tooltipLabelY}}
                        class="tooltip-label"
                      >
                        {{this.hoveredPoint.label}}
                      </text>
                    {{/if}}
                    <text
                      x={{this.hoveredPoint.tooltipNameX}}
                      y={{this.hoveredPoint.tooltipSizeY}}
                      class="tooltip-size"
                    >
                      {{this.hoveredPoint.formattedSize}}
                    </text>
                  </g>
                {{/if}}
              </svg>
            </div>

            {{! Legend }}
            {{#if this.graphData.seriesPaths}}
              <div class="graph-legend">
                {{#each this.graphData.seriesPaths as |sp|}}
                  <span class="legend-item">
                    <span
                      class="legend-swatch"
                      style={{htmlSafe
                        (concat
                          "background-color: "
                          (if sp.color sp.color "var(--tertiary)")
                        )
                      }}
                    ></span>
                    {{sp.name}}
                  </span>
                {{/each}}
              </div>
            {{/if}}
          {{else}}
            <div class="no-history">
              <p>{{i18n "discourse_size.no_size_history"}}</p>
            </div>
          {{/if}}

          {{#if this.topContributors.length}}
            <div class="modal-contributors">
              <h5>{{i18n "discourse_size.top_contributors"}}</h5>
              <ol class="contributors-list">
                {{#each this.topContributors as |entry|}}
                  <li class="contributor-row">
                    <a
                      href="/u/{{entry.user.username}}"
                      class="contributor-user"
                    >
                      {{avatar entry.user imageSize="small"}}
                      <span class="contributor-username">
                        {{entry.user.username}}
                        {{#if (and entry.isBlocked this.canSeeBlockedStatus)}}
                          <span class="blocked-badge">{{i18n
                              "discourse_size.blocking.blocked"
                            }}</span>
                        {{/if}}
                      </span>
                    </a>
                    <div class="contributor-actions">
                      <span class="contributor-stats">
                        <span class="contributor-size">
                          {{i18n "discourse_size.size_impact"}}
                          {{entry.formattedSize}}</span>
                      </span>
                      {{#if this.canManageCharacter}}
                        {{#if (notEq entry.user.id this.currentUser.id)}}
                          {{#if entry.isBlocked}}
                            <DButton
                              @action={{fn this.unblockUser entry.user}}
                              @icon="check"
                              @title="discourse_size.blocking.unblock_user"
                              class="btn-success"
                            />
                          {{else}}
                            <DButton
                              @action={{fn this.blockUser entry.user}}
                              @icon="ban"
                              @title="discourse_size.blocking.block_user"
                              class="btn-danger"
                            />
                          {{/if}}
                        {{/if}}
                      {{/if}}
                    </div>
                  </li>
                {{/each}}
              </ol>
            </div>
          {{/if}}

          <div class="modal-activity-list">
            <h5>{{i18n "discourse_size.recent_activity"}}</h5>
            <ul>
              {{#each this.newestFirstActions as |activity|}}
                <li class="activity-item">
                  <div class="activity-user">
                    <LinkTo
                      @route="user.index"
                      @model={{activity.user.username}}
                    >
                      {{avatar activity.user imageSize="small"}}
                    </LinkTo>
                  </div>
                  <div class="activity-details">
                    <span class="activity-text">
                      <strong>
                        <LinkTo
                          @route="user.index"
                          @model={{activity.user.username}}
                        >{{activity.user.username}}</LinkTo>
                      </strong>
                      {{#if activity.parent_action_id}}
                        {{i18n "discourse_size.activity.used"}}
                        <LinkTo
                          @route="size-shop"
                          class="item-link"
                        >{{activity.item_name}}</LinkTo>
                        {{#if (eq activity.parent_action_type "grow")}}
                          {{i18n "discourse_size.activity.to_grow"}}
                        {{else}}
                          {{i18n "discourse_size.activity.to_shrink"}}
                        {{/if}}
                        <LinkTo
                          @route="user.characters.index"
                          @model={{activity.target_owner_username}}
                        >{{activity.target_character_name}}</LinkTo>
                        {{i18n "discourse_size.activity.by"}}
                        {{formatSize0
                          (abs activity.parent_size_change)
                          @model.character.measurement_system
                        }},
                        {{i18n "discourse_size.activity.causing"}}
                        <LinkTo
                          @route="user.characters.index"
                          @model={{activity.character_owner_username}}
                        >{{@model.character.name}}</LinkTo>
                        {{i18n "discourse_size.activity.to"}}
                        {{activity.action_type}}
                        {{i18n "discourse_size.activity.by"}}
                        {{formatSize0
                          (abs activity.size_change)
                          @model.character.measurement_system
                        }}
                      {{else if
                        (or
                          (eq activity.action_type "grow")
                          (eq activity.action_type "shrink")
                        )
                      }}
                        {{#if activity.item_name}}
                          {{i18n "discourse_size.activity.used"}}
                          <LinkTo
                            @route="size-shop"
                            class="item-link"
                          >{{activity.item_name}}</LinkTo>
                          {{i18n
                            (concat
                              "discourse_size.activity.to_" activity.action_type
                            )
                          }}
                        {{else}}
                          {{i18n
                            (concat
                              "discourse_size.activity."
                              (if
                                (eq activity.action_type "grow") "grew" "shrunk"
                              )
                            )
                          }}
                        {{/if}}
                        <LinkTo
                          @route="user.characters.index"
                          @model={{activity.character_owner_username}}
                        >{{@model.character.name}}</LinkTo>
                        {{i18n "discourse_size.activity.by"}}
                        {{formatSize0
                          (abs activity.size_change)
                          @model.character.measurement_system
                        }}{{#if activity.child_action_id}},
                          {{i18n "discourse_size.activity.causing"}}
                          <LinkTo
                            @route="user.characters.index"
                            @model={{activity.child_character_owner_username}}
                          >{{activity.child_character_name}}</LinkTo>
                          {{i18n "discourse_size.activity.to"}}
                          {{activity.child_action_type}}
                          {{i18n "discourse_size.activity.by"}}
                          {{formatSize0
                            (abs activity.child_size_change)
                            @model.character.measurement_system
                          }}
                        {{/if}}
                      {{else if (eq activity.action_type "reset")}}
                        {{i18n
                          "discourse_size.activity.reset"
                          character=@model.character.name
                        }}
                      {{else if (eq activity.action_type "trigger")}}
                        {{i18n
                          "discourse_size.activity.run_trigger"
                          trigger=activity.item_name
                          character=@model.character.name
                        }}
                      {{else if (eq activity.action_type "set_size")}}
                        {{i18n "discourse_size.activity.set_size_to"}}
                        {{formatSize0
                          @model.character.current_size
                          @model.character.measurement_system
                        }}
                      {{else if (eq activity.action_type "property_change")}}
                        {{i18n
                          "discourse_size.activity.property_change"
                          property=activity.item_name
                        }}
                      {{else if (eq activity.action_type "boost_speed")}}
                        {{i18n "discourse_size.activity.boost_speed"}}
                        +{{activity.size_change}}% / day
                      {{else}}
                        {{i18n
                          "discourse_size.activity.unknown"
                          character=@model.character.name
                          type=activity.action_type
                        }}
                      {{/if}}
                    </span>

                    <span class="date">{{formatDate
                        activity.created_at
                        leaveAgo="true"
                      }}</span>

                    {{#if
                      (and
                        this.canManageCharacter (not activity.parent_action_id)
                      )
                    }}
                      <DButton
                        @action={{fn this.deleteAction activity}}
                        @icon="clock-rotate-left"
                        class="btn-danger btn-small delete-action-btn"
                        @title="discourse_size.delete_action"
                      />
                    {{/if}}
                  </div>
                </li>
              {{/each}}
            </ul>
          </div>
        </div>
      </:body>
    </DModal>
  </template>
}
