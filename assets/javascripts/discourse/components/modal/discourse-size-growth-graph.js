import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action, notifyPropertyChange } from "@ember/object";
import { i18n } from "discourse-i18n";
import { formatSize } from "../../lib/size-formatter";
import { ajax } from "discourse/lib/ajax";
import { inject as service } from "@ember/service";

const SERIES_COLORS = [
  "#e74c3c", "#2ecc71", "#f39c12", "#9b59b6", "#1abc9c",
  "#e67e22", "#3498db", "#e91e63", "#00bcd4", "#8bc34a",
];

export default class DiscourseSizeGrowthGraph extends Component {
  @tracked hoveredPoint = null;
  @tracked _character = null;
  @service currentUser;
  @service siteSettings;

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
    if (!this.currentUser) return false;
    const char = this.character;
    return this.currentUser.id === char?.user_id || this.currentUser.admin;
  }

  get series() {
    const char = this.character;
    if (!char || !char.actions) return [];

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
      .sort(
        (a, b) => new Date(a.start_time) - new Date(b.start_time)
      );

    const sizePoints = [];
    sizePoints.push({
      date: new Date(char.created_at),
      value: parseFloat(char.base_size) || 0,
      label: "Created",
    });
    sizeActions.forEach((a) => {
      const val = (parseFloat(char.base_size) || 0) + (parseFloat(a.end_offset) || 0);
      sizePoints.push({
        date: new Date(a.end_time),
        value: val,
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
        .sort(
          (a, b) => new Date(a.start_time) - new Date(b.start_time)
        );

      if (propActions.length === 0) return;

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
    if (allSeries.length === 0 || allSeries.every((s) => s.points.length < 2))
      return null;

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
        const tooltipX = Math.min(x + 10, width - 190);
        const tooltipY = Math.max(y - 70, 10);

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
          tooltipNameX: tooltipX + 10,
          tooltipNameY: tooltipY + 20,
          tooltipSizeX: tooltipX + 10,
          tooltipSizeY: tooltipY + 40,
          formattedSize: formatSize(p.value, this.preferredSystem),
        };
      });

      let path = "";
      for (let i = 0; i < pts.length; i++) {
        path += i === 0 ? `M ${pts[i].x} ${pts[i].y}` : ` L ${pts[i].x} ${pts[i].y}`;
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
      if (!userId) return;
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

    if (!confirm(i18n(key))) return;

    try {
      const result = await ajax(`/size/actions/${actionItem.id}`, {
        type: "DELETE",
      });
      if (result.character) {
        this.args.model.onActionDeleted?.(result.character);
      }

      this.character.actions = this.character.actions.filter(
        (action) => action.id !== actionItem.id
      );
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
        I18n.t("discourse_size.blocking.confirm_block_user", {
          username: user.username,
        })
      )
    ) return;

    try {
      await ajax(`/size/characters/${this.character.id}/block_user`, {
        type: "POST",
        data: { user_id: user.id },
      });
      this.character.blocked_user_ids.push(user.id);
      notifyPropertyChange(this, "topContributors");
    } catch (e) {
      alert("Error blocking user");
    }
  }

  @action
  async unblockUser(user) {
    if (
      !confirm(
        I18n.t("discourse_size.blocking.confirm_block_user", {
          username: user.username,
        })
      )
    ) return;

    try {
      await ajax(`/size/characters/${this.character.id}/unblock_user`, {
        type: "POST",
        data: { user_id: user.id },
      });
      this.character.blocked_user_ids = this.character.blocked_user_ids.filter(
        (id) => id !== user.id
      );
      notifyPropertyChange(this, "topContributors");
    } catch (e) {
      alert("Error unblocking user");
    }
  }
}
