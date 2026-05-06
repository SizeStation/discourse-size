import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action, notifyPropertyChange } from "@ember/object";
import { i18n } from "discourse-i18n";
import { formatSize } from "../../lib/size-formatter";
import { ajax } from "discourse/lib/ajax";
import { inject as service } from "@ember/service";

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

  get actions() {
    return this.character?.actions || [];
  }

  get canManageCharacter() {
    return (
      this.currentUser?.admin ||
      this.character?.user_id === this.currentUser?.id
    );
  }

  get oldestFirstActions() {
    if (!this.args) return [];
    return this.actions.slice().reverse();
  }

  get newestFirstActions() {
    if (!this.args) return [];
    return this.actions;
  }

  get canSeeBlockedStatus() {
    if (!this.currentUser) return false;
    const char = this.character;
    return this.currentUser.id === char?.user_id || this.currentUser.admin;
  }

  get history() {
    if (!this.args) return [];
    const char = this.character;
    if (!char) return [];
    const history = [];
    let cumulativeSize = parseFloat(char.base_size);

    // 1. Creation Point
    history.push({
      date: new Date(char.created_at),
      size: cumulativeSize,
      label: "Created",
      isProjection: false,
    });

    // 2. Action Points
    this.oldestFirstActions.forEach((action) => {
      if (
        action.action_type === "grow" ||
        action.action_type === "shrink" ||
        action.action_type === "set_size"
      ) {
        cumulativeSize += parseFloat(action.size_change);
      }
      history.push({
        date: new Date(action.created_at),
        size: cumulativeSize,
        action,
        isProjection: false,
      });
    });

    // 3. Target Point (Projection)
    const currentSize = parseFloat(char.current_size);
    const targetSize =
      parseFloat(char.base_size) + parseFloat(char.target_offset);
    if (Math.abs(targetSize - currentSize) > 0.1) {
      // Calculate how long it will take to reach target
      const rate =
        char.growth_rate_override ||
        this.siteSettings.discourse_size_default_max_growth_rate;
      const multiplier = char.growth_speed_multiplier || 1.0;
      const effectiveRate = rate * multiplier;

      if (effectiveRate > 0) {
        const diff = Math.abs(targetSize - currentSize);
        const daysToTarget = diff / effectiveRate;
        const targetDate = new Date();
        targetDate.setTime(targetDate.getTime() + daysToTarget * 86400000);

        history.push({
          date: targetDate,
          size: targetSize,
          label: "Target",
          isProjection: true,
        });
      }
    }

    return history;
  }

  get graphData() {
    const history = this.history;
    if (history.length < 2) return null;

    const width = 800;
    const height = 400;
    const paddingX = 80;
    const paddingY = 60;

    const minSize = Math.max(0, Math.min(...history.map((h) => h.size)));
    const maxSize = Math.max(...history.map((h) => h.size));
    const sizeRange = maxSize - minSize || 1;

    // Use equal spacing for X to prevent clustering as requested
    const points = history.map((h, i) => {
      const x = paddingX + (i / (history.length - 1)) * (width - 2 * paddingX);
      const y =
        height -
        paddingY -
        (sizeRange > 0
          ? ((h.size - minSize) / sizeRange) * (height - 2 * paddingY)
          : height / 2 - paddingY);

      return {
        x,
        y,
        size: h.size,
        date: h.date,
        action: h.action,
        label: h.label,
        isProjection: h.isProjection,
        tooltipX: x,
        tooltipY: y - 70,
        tooltipNameX: x + 10,
        tooltipNameY: y - 45,
        tooltipSizeX: x + 10,
        tooltipSizeY: y - 25,
        formattedSize: formatSize(h.size, this.character?.measurement_system),
      };
    });

    let mainPath = `M ${points[0].x} ${points[0].y}`;
    let projectionPath = "";

    for (let i = 1; i < points.length; i++) {
      if (points[i].isProjection) {
        if (!projectionPath)
          projectionPath = `M ${points[i - 1].x} ${points[i - 1].y}`;
        projectionPath += ` L ${points[i].x} ${points[i].y}`;
      } else {
        mainPath += ` L ${points[i].x} ${points[i].y}`;
      }
    }

    return {
      points,
      mainPath,
      projectionPath,
      width,
      height,
      minSize,
      maxSize,
    };
  }

  get formattedMinSize() {
    return formatSize(
      this.graphData?.minSize || 0,
      this.character?.measurement_system
    );
  }

  get formattedMaxSize() {
    return formatSize(
      this.graphData?.maxSize || 0,
      this.character?.measurement_system
    );
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
        formattedSize: formatSize(
          entry.totalImpactCm,
          this.character?.measurement_system
        ),
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
        this.args.model.onActionDeleted?.(result.character);
      }
      
      this.character.actions = this.character.actions.filter(
        (action) => action.id !== actionItem.id
      );
      notifyPropertyChange(this, "history");
      notifyPropertyChange(this, "graphData");
      notifyPropertyChange(this, "actions");
      notifyPropertyChange(this, "newestFirstActions");
      notifyPropertyChange(this, "oldestFirstActions");
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
    ) {
      return;
    }

    try {
      const result = await ajax(
        `/size/characters/${this.character.id}/block_user`,
        {
          type: "POST",
          data: { user_id: user.id },
        }
      );
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
        I18n.t("discourse_size.blocking.confirm_unblock_user", {
          username: user.username,
        })
      )
    ) {
      return;
    }

    try {
      const result = await ajax(
        `/size/characters/${this.character.id}/unblock_user`,
        {
          type: "POST",
          data: { user_id: user.id },
        }
      );
      this.character.blocked_user_ids = this.character.blocked_user_ids.filter(
        (id) => id !== user.id
      );
      notifyPropertyChange(this, "topContributors");
    } catch (e) {
      alert("Error unblocking user");
    }
  }
}
