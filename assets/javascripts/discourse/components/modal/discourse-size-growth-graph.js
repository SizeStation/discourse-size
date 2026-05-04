import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { formatSize } from "../../lib/size-formatter";

export default class DiscourseSizeGrowthGraph extends Component {
  @tracked hoveredPoint = null;

  get oldestFirstActions() {
    if (!this.args) return [];
    // Character actions come in newest-first, so we reverse for history calculation
    return (this.args.model?.character?.actions || []).slice().reverse();
  }

  get newestFirstActions() {
    if (!this.args) return [];
    return this.args.model?.character?.actions || [];
  }

  get history() {
    if (!this.args) return [];
    const char = this.args.model?.character;
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
      if (action.action_type === "grow" || action.action_type === "shrink") {
        cumulativeSize += parseFloat(action.size_change);
      }
      history.push({
        date: new Date(action.created_at),
        size: cumulativeSize,
        action,
        isProjection: false,
      });
    });

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
        formattedSize: formatSize(
          h.size,
          this.args.model?.character?.measurement_system
        ),
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
      this.args.model?.character?.measurement_system
    );
  }

  get formattedMaxSize() {
    return formatSize(
      this.graphData?.maxSize || 0,
      this.args.model?.character?.measurement_system
    );
  }

  get topContributors() {
    const actions = this.args.model?.character?.actions || [];
    const byUser = {};

    for (const a of actions) {
      if (a.action_type === "reset" || a.action_type === "boost_speed") {
        continue;
      }
      const uid = a.user.id;
      if (!byUser[uid]) {
        byUser[uid] = {
          user: a.user,
          totalPoints: 0,
          totalSizeCm: 0,
        };
      }
      byUser[uid].totalPoints += a.points_spent || 0;
      // absolute cm contributed (grow = positive, shrink = negative)
      byUser[uid].totalSizeCm += a.size_change || 0;
    }

    return Object.values(byUser)
      .sort((a, b) => b.totalPoints - a.totalPoints)
      .slice(0, 10)
      .map((entry) => ({
        ...entry,
        formattedSize: formatSize(
          Math.abs(entry.totalSizeCm),
          this.args.model?.character?.measurement_system
        ),
        totalPoints: Math.round(entry.totalPoints),
        netEffect: entry.totalSizeCm >= 0 ? "grow" : "shrink",
      }));
  }

  @action
  setHoveredPoint(point) {
    this.hoveredPoint = point;
  }
}
