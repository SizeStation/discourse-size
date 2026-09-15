import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, notifyPropertyChange } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { and, eq, not, notEq, or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import avatar from "discourse/helpers/avatar";
import formatDate from "discourse/helpers/format-date";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import abs from "../../helpers/abs";
import formatSize0 from "../../helpers/format-size";
import {
  calculatePropertyValue,
  calculateSize,
} from "../../lib/size-calculator";
import { formatSize } from "../../lib/size-formatter";

function formatDateYMD(d) {
  const date = new Date(d);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

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
  @service dialog;

  @tracked hoveredPoint = null;
  @tracked startDate = formatDateYMD(Date.now() - 7 * 86400000);
  @tracked endDate = formatDateYMD(Date.now());
  @tracked visibleActionsLimit = 100;
  @tracked _character = null;
  _intersectionObserver = null;
  _isLoadingMore = false;

  willDestroy() {
    super.willDestroy(...arguments);
    this._disconnectObserver();
  }

  _disconnectObserver() {
    if (this._intersectionObserver) {
      this._intersectionObserver.disconnect();
      this._intersectionObserver = null;
    }
  }

  @action
  setupSentinel(element) {
    this._disconnectObserver();
    if (
      !element ||
      typeof window === "undefined" ||
      !window.IntersectionObserver
    ) {
      return;
    }
    this._intersectionObserver = new IntersectionObserver(
      (entries) => {
        if (
          entries[0]?.isIntersecting &&
          this.hasMoreActions &&
          !this._isLoadingMore
        ) {
          this._isLoadingMore = true;
          this.loadMoreActions();
          requestAnimationFrame(() => {
            this._isLoadingMore = false;
          });
        }
      },
      { rootMargin: "200px" }
    );
    this._intersectionObserver.observe(element);
  }

  @action
  loadMoreActions() {
    this.visibleActionsLimit += 100;
  }

  get startRange() {
    if (!this.startDate) {
      return null;
    }
    const d = new Date(`${this.startDate}T00:00:00`);
    return isNaN(d.getTime()) ? null : d;
  }

  get endRange() {
    if (!this.endDate) {
      return null;
    }
    const d = new Date(`${this.endDate}T23:59:59.999`);
    return isNaN(d.getTime()) ? null : d;
  }

  @action
  onStartDateChange(event) {
    this.startDate = event.target.value;
  }

  @action
  onEndDateChange(event) {
    this.endDate = event.target.value;
  }

  @action
  resetToLast7Days() {
    this.startDate = formatDateYMD(Date.now() - 7 * 86400000);
    this.endDate = formatDateYMD(Date.now());
  }

  @action
  setAllTime() {
    this.startDate = "";
    this.endDate = "";
  }

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
    return (this.character?.actions || []).filter(
      (a) =>
        !a.parent_action_id ||
        a.target_character_name ||
        (a.target_character_id && a.target_character_id !== a.character_id)
    );
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

  get visibleNewestFirstActions() {
    return this.newestFirstActions.slice(0, this.visibleActionsLimit);
  }

  get hasMoreActions() {
    return this.visibleActionsLimit < this.newestFirstActions.length;
  }

  get calculatedSizeCm() {
    return calculateSize(this.character);
  }

  get isMaxSize() {
    if (this.character?.is_max_size) {
      return true;
    }
    const size = this.calculatedSizeCm;
    return size >= 1e120 || (1e120 - size) / 1e120 < 1e-12;
  }

  get isMinSize() {
    if (this.character?.is_min_size) {
      return true;
    }
    const size = this.calculatedSizeCm;
    return size <= 1e-35 || (size - 1e-35) / 1e-35 < 1e-12;
  }

  get modalTitle() {
    const name = this.character?.name;
    if (!name) {
      return i18n("discourse_size.size_history");
    }
    if (this.isMaxSize) {
      return i18n("discourse_size.history_title_with_limit", {
        name,
        limit: i18n("discourse_size.max_size"),
      });
    } else if (this.isMinSize) {
      return i18n("discourse_size.history_title_with_limit", {
        name,
        limit: i18n("discourse_size.min_size"),
      });
    }
    return i18n("discourse_size.history_title", { name });
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
    const startRange = this.startRange;
    const endRange = this.endRange;

    // --- Size series ---
    const sizeActions = allActions
      .filter(
        (a) =>
          ["grow", "shrink", "set_size"].includes(a.action_type) &&
          a.start_time &&
          a.end_time
      )
      .sort((a, b) => {
        const timeDiff = new Date(a.start_time) - new Date(b.start_time);
        if (timeDiff !== 0) {
          return timeDiff;
        }
        const createdDiff =
          new Date(a.created_at || 0) - new Date(b.created_at || 0);
        if (createdDiff !== 0) {
          return createdDiff;
        }
        return (a.id || 0) - (b.id || 0);
      });

    if (sizeActions.length > 0) {
      const sizePoints = [];

      if (startRange) {
        // Start of window
        sizePoints.push({
          date: startRange,
          value: calculateSize(char, startRange),
          actionIdx: -1,
          isEnd: false,
        });

        const inWindow = sizeActions.filter((a) => {
          const aStart = new Date(a.start_time);
          const aEnd = new Date(a.end_time);
          return aEnd >= startRange && (!endRange || aStart <= endRange);
        });

        inWindow.forEach((a, idx) => {
          const aStart = new Date(a.start_time);
          const aEnd = new Date(a.end_time);
          const startVal =
            (parseFloat(char.base_size) || 0) +
            (parseFloat(a.start_offset) || 0);
          const endVal =
            (parseFloat(char.base_size) || 0) + (parseFloat(a.end_offset) || 0);

          if (aStart >= startRange && (!endRange || aStart <= endRange)) {
            sizePoints.push({
              date: aStart,
              value: startVal,
              actionIdx: idx,
              isEnd: false,
            });
          }

          if (!endRange || aEnd <= endRange) {
            sizePoints.push({
              date: aEnd,
              value: endVal,
              action: a,
              actionIdx: idx,
              isEnd: true,
            });
          } else {
            sizePoints.push({
              date: endRange,
              value: calculateSize(char, endRange),
              action: a,
              actionIdx: idx,
              isEnd: true,
            });
          }
        });

        if (endRange) {
          sizePoints.push({
            date: endRange,
            value: calculateSize(char, endRange),
            actionIdx: Infinity,
            isEnd: true,
          });
        }
      } else {
        // All time
        sizeActions.forEach((a, idx) => {
          const aStart = new Date(a.start_time);
          const aEnd = new Date(a.end_time);
          const startVal =
            (parseFloat(char.base_size) || 0) +
            (parseFloat(a.start_offset) || 0);
          const endVal =
            (parseFloat(char.base_size) || 0) + (parseFloat(a.end_offset) || 0);

          sizePoints.push({
            date: aStart,
            value: startVal,
            actionIdx: idx,
            isEnd: false,
          });

          sizePoints.push({
            date: aEnd,
            value: endVal,
            action: a,
            actionIdx: idx,
            isEnd: true,
          });
        });

        const now = new Date();
        sizePoints.push({
          date: now,
          value: calculateSize(char, now),
          actionIdx: Infinity,
          isEnd: true,
        });
      }

      sizePoints.sort((p1, p2) => {
        const dateDiff = p1.date.getTime() - p2.date.getTime();
        if (dateDiff !== 0) {
          return dateDiff;
        }
        if (p1.actionIdx !== p2.actionIdx) {
          return p1.actionIdx - p2.actionIdx;
        }
        return (p1.isEnd ? 1 : 0) - (p2.isEnd ? 1 : 0);
      });

      // Deduplicate consecutive identical points
      const deduped = [];
      sizePoints.forEach((p) => {
        const prev = deduped[deduped.length - 1];
        if (
          prev &&
          prev.date.getTime() === p.date.getTime() &&
          prev.value === p.value
        ) {
          if (p.action && !prev.action) {
            prev.action = p.action;
          }
          return;
        }
        deduped.push(p);
      });

      if (deduped.length > 0) {
        result.push({
          name: i18n("discourse_size.fields.size"),
          key: "__size__",
          points: deduped,
          color: null,
        });
      }
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
        .sort((a, b) => {
          const timeDiff = new Date(a.start_time) - new Date(b.start_time);
          if (timeDiff !== 0) {
            return timeDiff;
          }
          const createdDiff =
            new Date(a.created_at || 0) - new Date(b.created_at || 0);
          if (createdDiff !== 0) {
            return createdDiff;
          }
          return (a.id || 0) - (b.id || 0);
        });

      if (propActions.length === 0) {
        return;
      }

      const points = [];

      if (startRange) {
        const initialPropVal = calculatePropertyValue(char, name, startRange);
        if (initialPropVal !== undefined) {
          points.push({
            date: startRange,
            value: initialPropVal,
            actionIdx: -1,
            isEnd: false,
          });
        }

        const inWindow = propActions.filter((a) => {
          const aStart = new Date(a.start_time);
          const aEnd = new Date(a.end_time);
          return aEnd >= startRange && (!endRange || aStart <= endRange);
        });

        inWindow.forEach((a, aIdx) => {
          const aStart = new Date(a.start_time);
          const aEnd = new Date(a.end_time);
          const startVal = parseFloat(a.start_offset || 0);
          const endVal = parseFloat(a.end_offset || 0);

          if (aStart >= startRange && (!endRange || aStart <= endRange)) {
            points.push({
              date: aStart,
              value: startVal,
              actionIdx: aIdx,
              isEnd: false,
            });
          }

          if (!endRange || aEnd <= endRange) {
            points.push({
              date: aEnd,
              value: endVal,
              action: a,
              actionIdx: aIdx,
              isEnd: true,
            });
          } else {
            const endValInterp = calculatePropertyValue(char, name, endRange);
            points.push({
              date: endRange,
              value: endValInterp,
              action: a,
              actionIdx: aIdx,
              isEnd: true,
            });
          }
        });

        if (endRange) {
          const endVal = calculatePropertyValue(char, name, endRange);
          if (endVal !== undefined) {
            points.push({
              date: endRange,
              value: endVal,
              actionIdx: Infinity,
              isEnd: true,
            });
          }
        }
      } else {
        propActions.forEach((a, aIdx) => {
          const aStart = new Date(a.start_time);
          const aEnd = new Date(a.end_time);
          const startVal = parseFloat(a.start_offset || 0);
          const endVal = parseFloat(a.end_offset || 0);

          points.push({
            date: aStart,
            value: startVal,
            actionIdx: aIdx,
            isEnd: false,
          });

          points.push({
            date: aEnd,
            value: endVal,
            action: a,
            actionIdx: aIdx,
            isEnd: true,
          });
        });
      }

      points.sort((p1, p2) => {
        const dateDiff = p1.date.getTime() - p2.date.getTime();
        if (dateDiff !== 0) {
          return dateDiff;
        }
        if (p1.actionIdx !== p2.actionIdx) {
          return p1.actionIdx - p2.actionIdx;
        }
        return (p1.isEnd ? 1 : 0) - (p2.isEnd ? 1 : 0);
      });

      const dedupedPropPoints = [];
      points.forEach((p) => {
        const prev = dedupedPropPoints[dedupedPropPoints.length - 1];
        if (
          prev &&
          prev.date.getTime() === p.date.getTime() &&
          prev.value === p.value
        ) {
          if (p.action && !prev.action) {
            prev.action = p.action;
          }
          return;
        }
        dedupedPropPoints.push(p);
      });

      if (dedupedPropPoints.length > 0) {
        result.push({
          name,
          key: name,
          points: dedupedPropPoints,
          color: SERIES_COLORS[idx % SERIES_COLORS.length],
        });
      }
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

    let minVal = Math.min(...allValues);
    let maxVal = Math.max(...allValues);
    if (minVal === maxVal) {
      minVal = Math.max(0, minVal * 0.9);
      maxVal = maxVal * 1.1 || 1;
    }
    const valRange = maxVal - minVal || 1;

    const earliest =
      this.startRange ||
      (allDates.length > 0 ? new Date(Math.min(...allDates)) : new Date());
    const latest =
      this.endRange ||
      (allDates.length > 0 ? new Date(Math.max(...allDates)) : new Date());
    const timeRange = latest.getTime() - earliest.getTime() || 1;

    const dateFormatter = new Intl.DateTimeFormat(undefined, {
      month: "short",
      day: "numeric",
    });
    const dateTimeFormatter = new Intl.DateTimeFormat(undefined, {
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
    });

    const seriesPaths = [];
    const flatPoints = [];

    allSeries.forEach((s) => {
      const pts = s.points.map((p) => {
        const timeRatio = Math.max(
          0,
          Math.min(1, (p.date.getTime() - earliest.getTime()) / timeRange)
        );
        const x = paddingX + timeRatio * (width - 2 * paddingX);
        const y =
          height -
          paddingY -
          ((p.value - minVal) / valRange) * (height - 2 * paddingY);
        const tooltipWidth = 190;
        const tooltipHeight = p.label ? 82 : 68;
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
          formattedDate: dateTimeFormatter.format(p.date),
          action: p.action,
          label: p.label,
          seriesKey: s.key,
          seriesName: s.name,
          tooltipX,
          tooltipY,
          tooltipWidth,
          tooltipHeight,
          tooltipNameX: tooltipX + 12,
          tooltipNameY: tooltipY + 20,
          tooltipDateY: tooltipY + 34,
          tooltipLabelY: tooltipY + 48,
          tooltipSizeY: p.label ? tooltipY + 64 : tooltipY + 52,
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
      formattedStartDate: dateFormatter.format(earliest),
      formattedEndDate: dateFormatter.format(latest),
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

    actions.forEach((act) => {
      if (
        act.action_type === "reset" ||
        act.action_type === "boost_speed" ||
        !act.size_change
      ) {
        return;
      }
      const userId = act.user_id || act.user?.id;
      if (!userId) {
        return;
      }
      if (!byUser[userId]) {
        byUser[userId] = {
          user: act.user,
          totalImpactCm: 0,
          totalPoints: 0,
        };
      }
      byUser[userId].totalImpactCm += parseFloat(act.size_change || 0);
      byUser[userId].totalPoints += parseFloat(act.points_spent || 0);
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
  deleteAction(actionItem) {
    if (actionItem.parent_action_id && !this.currentUser.admin) {
      this.dialog.alert(
        i18n("discourse_size.activity.self_effect_delete_error")
      );
      return;
    }

    const key =
      actionItem.item_key || actionItem.points_spent > 0
        ? "discourse_size.delete_action_with_return_confirm"
        : "discourse_size.delete_action_confirm";

    this.dialog.confirm({
      message: i18n(key),
      didConfirm: async () => {
        try {
          const result = await ajax(`/size/actions/${actionItem.id}`, {
            type: "DELETE",
          });
          if (result.character) {
            this.character = result.character;
            this.args.model.onActionDeleted?.(result.character);
          } else {
            this.character.actions = this.character.actions.filter(
              (act) => act.id !== actionItem.id
            );
          }

          notifyPropertyChange(this, "character");
          notifyPropertyChange(this, "series");
          notifyPropertyChange(this, "graphData");
          notifyPropertyChange(this, "actions");
          notifyPropertyChange(this, "newestFirstActions");
          notifyPropertyChange(this, "topContributors");
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  @action
  blockUser(user) {
    this.dialog.confirm({
      message: i18n("discourse_size.blocking.confirm_block_user", {
        username: user.username,
      }),
      didConfirm: async () => {
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
          popupAjaxError(e);
        }
      },
    });
  }

  @action
  unblockUser(user) {
    this.dialog.confirm({
      message: i18n("discourse_size.blocking.confirm_unblock_user", {
        username: user.username,
      }),
      didConfirm: async () => {
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
          popupAjaxError(e);
        }
      },
    });
  }

  <template>
    <DModal
      @title={{this.modalTitle}}
      @closeModal={{@closeModal}}
      class="discourse-size-growth-graph-modal"
    >
      <:body>
        <div class="growth-graph-container">
          <div class="growth-graph-toolbar">
            <div class="growth-graph-toolbar__date-group">
              <label
                class="growth-graph-toolbar__label"
                for="growth-graph-start-date"
              >
                {{i18n "discourse_size.graph.start_date"}}
              </label>
              <input
                id="growth-graph-start-date"
                type="date"
                class="growth-graph-toolbar__input"
                value={{this.startDate}}
                {{on "input" this.onStartDateChange}}
              />
            </div>
            <div class="growth-graph-toolbar__date-group">
              <label
                class="growth-graph-toolbar__label"
                for="growth-graph-end-date"
              >
                {{i18n "discourse_size.graph.end_date"}}
              </label>
              <input
                id="growth-graph-end-date"
                type="date"
                class="growth-graph-toolbar__input"
                value={{this.endDate}}
                {{on "input" this.onEndDateChange}}
              />
            </div>
            <div class="growth-graph-toolbar__presets">
              <DButton
                class="btn-default btn-small"
                @label="discourse_size.graph.last_7_days"
                @action={{this.resetToLast7Days}}
              />
              <DButton
                class="btn-default btn-small"
                @label="discourse_size.graph.all_time"
                @action={{this.setAllTime}}
              />
            </div>
          </div>

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

                {{! X Axis Date Labels }}
                {{#if this.graphData.formattedStartDate}}
                  <text
                    x="80"
                    y="360"
                    text-anchor="start"
                    class="axis-label"
                  >{{this.graphData.formattedStartDate}}</text>
                {{/if}}
                {{#if this.graphData.formattedEndDate}}
                  <text
                    x="720"
                    y="360"
                    text-anchor="end"
                    class="axis-label"
                  >{{this.graphData.formattedEndDate}}</text>
                {{/if}}

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
                    <text
                      x={{this.hoveredPoint.tooltipNameX}}
                      y={{this.hoveredPoint.tooltipDateY}}
                      class="tooltip-date"
                    >
                      {{this.hoveredPoint.formattedDate}}
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
                      style={{trustHTML
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
              {{#each this.visibleNewestFirstActions as |activity|}}
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

            {{#if this.hasMoreActions}}
              <div
                class="modal-activity-list__sentinel"
                {{didInsert this.setupSentinel}}
              >
                <DButton
                  @action={{this.loadMoreActions}}
                  @label="discourse_size.graph.load_more"
                  class="btn-default modal-activity-list__load-more-btn"
                />
              </div>
            {{/if}}
          </div>
        </div>
      </:body>
    </DModal>
  </template>
}
