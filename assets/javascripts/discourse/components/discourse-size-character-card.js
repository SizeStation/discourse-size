import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import {
  calculateSize,
  isAnimating,
  getTimeRemaining,
  calculatePropertyValue,
} from "../lib/size-calculator";
import {
  formatSize,
  getComparison,
  getGrowthComparison,
} from "../lib/size-formatter";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseSizeGrowthGraph from "./modal/discourse-size-growth-graph";

export default class DiscourseSizeCharacterCard extends Component {
  @service currentUser;
  @service modal;
  @service siteSettings;

  @tracked _currentTime = new Date();
  @tracked floatingWords = [];
  @tracked thrownItem = null;
  @tracked _lastActionId = null;
  _timer = null;
  _wordTimer = 0;

  GROW_WORDS = ["stretches", "grows", "swells", "bigger", "expands"];
  SHRINK_WORDS = ["dwindles", "shrinks", "smaller"];

  constructor() {
    super(...arguments);

    // Initialize actions
    const actions = this.args?.character?.actions || [];
    this._lastActionId = actions[0]?.id;

    this._timer = setInterval(() => {
      const now = new Date();
      this._currentTime = now;
      if (this.isAnimating) {
        this._tickWords(now);
      }
      this._checkForNewActions();
    }, 100);
  }

  _checkForNewActions() {
    const actions = this.args?.character?.actions || [];
    const latestAction = actions[0];
    const latestId = latestAction?.id;

    if (latestId && latestId !== this._lastActionId) {
      // New action detected!
      if (
        latestAction.item_picture &&
        (latestAction.action_type === "grow" ||
          latestAction.action_type === "shrink")
      ) {
        const createdAt = new Date(latestAction.created_at);
        if (Date.now() - createdAt.getTime() < 15000) {
          this._triggerThrowAnimation(latestAction);
        }
      }
      this._lastActionId = latestId;
    }
  }

  _triggerThrowAnimation(action) {
    this.thrownItem = {
      picture: action.item_picture,
      startX:
        (Math.random() > 0.5 ? 1 : -1) * (300 + Math.random() * 100) + "px",
      startY:
        (Math.random() > 0.5 ? 1 : -1) * (300 + Math.random() * 100) + "px",
    };

    setTimeout(() => {
      this.thrownItem = null;
    }, 1200);
  }

  _tickWords(now) {
    const multiplier = this.animationMultiplier;
    const baseInterval = 1000; // ms
    const interval = baseInterval / multiplier;

    if (now - this._wordTimer > interval) {
      this._wordTimer = now;
      this._spawnWord();
    }
  }

  _spawnWord() {
    if (!this.activeActionType) return;

    const isGrow = this.activeActionType === "grow";
    const wordList = isGrow ? this.GROW_WORDS : this.SHRINK_WORDS;
    const rawText = wordList[Math.floor(Math.random() * wordList.length)];
    const text = `*${rawText.toLowerCase()}*`;

    const multiplier = this.animationMultiplier;
    const duration = 2000 / multiplier;

    const newWord = {
      id: Math.random().toString(36).substr(2, 9),
      text,
      type: this.activeActionType,
      style: this._getRandomWordStyle(duration),
    };

    this.floatingWords = [...this.floatingWords, newWord];

    // Remove after animation
    setTimeout(() => {
      this.floatingWords = this.floatingWords.filter(
        (w) => w.id !== newWord.id
      );
    }, duration);
  }

  _getRandomWordStyle(duration) {
    // Keep it on the picture area
    const top = 15 + Math.random() * 70;
    const left = 15 + Math.random() * 70;
    const rotate = (Math.random() - 0.5) * 30;

    const tx = (Math.random() - 0.5) * 60 + "px";
    const ty = (Math.random() - 0.5) * 60 + "px";

    return `top: ${top}%; left: ${left}%; --rot: ${rotate}deg; --tx: ${tx}; --ty: ${ty}; animation-duration: ${duration}ms;`;
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this._timer) {
      clearInterval(this._timer);
    }
  }

  get canEdit() {
    return this.args?.isCurrentUser || this.currentUser?.admin;
  }

  get showActions() {
    if (!this.currentUser) return false;
    const char = this.args?.character;
    if (!char) return false;

    // Owner and admin can always see actions
    if (this.currentUser.id === char.user_id || this.currentUser.admin) {
      return true;
    }

    // Freeform characters only allow owner/admin to take actions
    if (char.character_type === "normal") return false;

    // Show actions for everyone logged in (the component handles the blocked button)
    return true;
  }

  get calculatedSizeCm() {
    return calculateSize(this.args?.character, this._currentTime);
  }

  get preferredSystem() {
    return (
      this.currentUser?.discourse_size_settings?.measurement_system ||
      this.args?.character?.measurement_system ||
      "imperial"
    );
  }

  get formattedSize() {
    return formatSize(this.calculatedSizeCm, this.preferredSystem);
  }

  get targetSizeCm() {
    const active = this.activeAction;
    if (active) {
      return (
        parseFloat(this.args?.character?.base_size) +
        parseFloat(active.end_offset)
      );
    }
    return (
      parseFloat(this.args?.character?.base_size) +
      parseFloat(this.args?.character?.target_offset)
    );
  }

  get formattedTargetSize() {
    return formatSize(this.targetSizeCm, this.preferredSystem);
  }

  get formattedStartSize() {
    const active = this.activeAction;
    const startOffset = active
      ? parseFloat(active.start_offset)
      : parseFloat(this.args?.character?.start_offset);

    return formatSize(
      parseFloat(this.args?.character?.base_size) + startOffset,
      this.preferredSystem
    );
  }

  get comparisonText() {
    const tempChar = Object.assign({}, this.args?.character, {
      current_size: this.calculatedSizeCm,
    });
    return getComparison(tempChar);
  }

  get growthComparisonText() {
    return getGrowthComparison(this.args?.character, this.calculatedSizeCm);
  }

  get hasDescription() {
    const c = this.args?.character;
    return c?.description || c?.info_post || c?.show_comparison;
  }

  get isAnimating() {
    return isAnimating(this.args?.character, this._currentTime);
  }

  get timeRemaining() {
    const c = this.args?.character;
    if (!c || !c.actions) return null;
    const now = this._currentTime;
    const actions = c.actions
      .filter(
        (a) => a.start_time && a.end_time && a.action_type !== "property_change"
      )
      .sort((a, b) => new Date(a.start_time) - new Date(b.start_time));
    const activeAction = actions.find((a) => {
      const start = new Date(a.start_time);
      const end = new Date(a.end_time);
      return now >= start && now < end;
    });
    if (!activeAction) return null;
    const remaining = new Date(activeAction.end_time) - now;
    if (remaining <= 0) return null;
    const mins = Math.floor(remaining / 60000);
    const secs = Math.floor((remaining % 60000) / 1000);
    if (mins > 0) return `${mins}m ${secs}s`;
    return `${secs}s`;
  }

  get activeAction() {
    const c = this.args?.character;
    if (!c || !c.actions) return null;
    const now = this._currentTime;
    return (c.actions || []).find((a) => {
      if (!a.start_time || !a.end_time) return false;
      if (a.action_type === "property_change") return false;
      const start = new Date(a.start_time);
      const end = new Date(a.end_time);
      return now >= start && now < end;
    });
  }

  get allPropertyActions() {
    const c = this.args?.character;
    if (!c || !c.actions) return [];
    const now = this._currentTime;

    const all = c.actions.filter((a) => a.action_type === "property_change");
    const grouped = {};
    all.forEach((a) => {
      if (!grouped[a.item_key]) {
        grouped[a.item_key] = {
          name: a.item_key,
          active: null,
          queued: [],
          all: [],
        };
      }
      grouped[a.item_key].all.push(a);
    });

    return Object.values(grouped).map((group) => {
      group.all.sort((a, b) => new Date(a.start_time) - new Date(b.start_time));

      const activeIdx = group.all.findIndex((a) => {
        if (!a.start_time || !a.end_time) return false;
        const start = new Date(a.start_time);
        const end = new Date(a.end_time);
        return now >= start && now < end;
      });

      if (activeIdx >= 0) {
        group.active = group.all[activeIdx];
        group.queued = group.all.slice(activeIdx + 1);

        const startT = new Date(group.active.start_time);
        const endT = new Date(group.active.end_time);
        const total = endT - startT;
        group._progress =
          total <= 0
            ? 100
            : Math.min(100, Math.max(0, ((now - startT) / total) * 100));

        const parent = c.actions.find(
          (p) => p.id === group.active.parent_action_id
        );
        group._triggerName = parent?.item_name;
        group._direction =
          parseFloat(group.active.end_offset) >
          parseFloat(group.active.start_offset)
            ? "Growing"
            : "Shrinking";
      } else {
        const futureIdx = group.all.findIndex((a) => {
          if (!a.start_time) return false;
          return new Date(a.start_time) > now;
        });
        if (futureIdx >= 0) {
          group.queued = group.all.slice(futureIdx);
        }
      }

      group._queueText = (group.queued || [])
        .map((q) => {
          const parent = c.actions.find((a) => a.id === q.parent_action_id);
          return parent?.item_name || parent?.item_key || q.item_name || q.item_key;
        })
        .join(", ");

      return group;
    });
  }

  get activePropertyActions() {
    return this.allPropertyActions
      .filter((g) => g.active)
      .map((g) => ({
        ...g.active,
        _progress: g._progress,
        _triggerName: g._triggerName,
        _direction: g._direction,
      }));
  }

  get allActiveProgressBars() {
    const bars = [];
    if (this.activeAction) {
      bars.push({ type: "size", action: this.activeAction });
    }
    this.activePropertyActions.forEach((a) => {
      bars.push({ type: "property", action: a });
    });
    return bars;
  }

  get effectiveProperties() {
    const props = this.args?.character?.properties || [];
    const actions = this.args?.character?.actions || [];
    const now = this._currentTime;
    return props.map((prop) => {
      const interpolated = calculatePropertyValue(
        this.args.character,
        prop.name,
        now
      );
      if (interpolated !== undefined) {
        const effectiveValue =
          prop.property_type === "size" || prop.property_type === "number"
            ? interpolated.toString()
            : Math.round(interpolated).toString();
        return { ...prop, effective_value: effectiveValue };
      }
      return prop;
    });
  }

  get activeActionType() {
    const action = this.activeAction;
    if (!action) return null;
    if (action.action_type === "set_size") {
      return parseFloat(action.size_change) >= 0 ? "grow" : "shrink";
    }
    return action.action_type;
  }

  get currentRateCmPerDay() {
    const active = this.activeAction;
    if (!active) return 0;

    const start = new Date(active.start_time);
    const end = new Date(active.end_time);
    const durationDays = (end - start) / (1000 * 60 * 60 * 24);
    if (durationDays <= 0) return 0;

    return Math.abs(active.end_offset - active.start_offset) / durationDays;
  }

  get animationMultiplier() {
    const rate = this.currentRateCmPerDay;
    if (rate <= 0) return 1;

    const logRate = Math.log10(rate + 1e-10);
    // Map logRate (-2 to 15) to a multiplier
    // -2 (fingernail) -> ~0.15
    // 2 (bamboo) -> ~0.66
    // 8 (highway) -> ~1.66
    // 15 (light speed) -> ~2.9
    const factor = (logRate + 2) / 6;
    return Math.max(0.1, Math.min(5, factor));
  }

  get pingStyle() {
    if (!this.isAnimating) return "";
    const multiplier = this.animationMultiplier;
    const duration = 2000 / multiplier;
    const scale = 1.2 + 0.2 * multiplier;

    return `--ping-duration: ${duration}ms; --ping-scale: ${scale};`;
  }

  get activeActionItemName() {
    const action = this.activeAction;
    if (!action) return I18n.t("discourse_size.unknown");
    if (action.parent_action_id) {
      const parent = (this.args?.character?.actions || []).find(
        (a) => a.id === action.parent_action_id
      );
      if (parent?.item_name) return parent.item_name;
    }
    return action.item_name || I18n.t("discourse_size.unknown");
  }

  get queuedActions() {
    const c = this.args?.character;
    if (!c || !c.actions) return [];
    const now = this._currentTime;
    const active = this.activeAction;

    return (c.actions || [])
      .filter((a) => {
        if (
          !a.start_time ||
          !["grow", "shrink", "set_size"].includes(a.action_type)
        )
          return false;
        const start = new Date(a.start_time);
        return start > now && (!active || a.id !== active.id);
      })
      .sort((a, b) => new Date(a.start_time) - new Date(b.start_time));
  }

  get formattedQueuedActions() {
    const c = this.args?.character;
    if (!c) return "";

    return this.queuedActions
      .map((a) => {
        return a.item_name || I18n.t("discourse_size.unknown");
      })
      .join(", ");
  }

  get progressPercent() {
    const activeAction = this.activeAction;
    if (!activeAction) return 0;

    const now = this._currentTime;
    const startT = new Date(activeAction.start_time);
    const endT = new Date(activeAction.end_time);
    const total = endT - startT;
    if (total <= 0) return 100;

    return Math.min(100, Math.max(0, ((now - startT) / total) * 100));
  }

  get isGrowing() {
    return this.targetSizeCm > this.calculatedSizeCm + 0.0001;
  }

  get recentActions() {
    const actions = this.args?.character?.actions || [];
    const topLevel = actions.filter((a) => !a.parent_action_id);
    return topLevel.slice(0, 5);
  }

  get pendingRoleplayInvites() {
    return (this.args.character.roleplay_memberships || []).filter(
      (m) => m.status === "pending"
    );
  }

  @action
  async acceptInvite(invite) {
    try {
      await ajax(`/size/roleplays/${invite.roleplay_id}/accept_invite`, {
        type: "POST",
        data: { character_id: this.args.character.id },
      });
      this.args.onAction?.();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async declineInvite(invite) {
    try {
      await ajax(`/size/roleplays/${invite.roleplay_id}/decline_invite`, {
        type: "POST",
        data: { character_id: this.args.character.id },
      });
      this.args.onAction?.();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  showGrowthGraph() {
    this.modal.show(DiscourseSizeGrowthGraph, {
      model: {
        character: this.args?.character,
        onActionDeleted: (updatedChar) => {
          this.args?.onAction?.(updatedChar);
        },
      },
    });
  }

  @action
  async adminEdit() {
    const AdminEditModal = (await import("./modal/discourse-size-admin-edit"))
      .default;
    this.modal.show(AdminEditModal, {
      model: {
        character: this.args?.character,
        onSave: (updatedChar) => {
          this.args?.onAction?.(updatedChar);
        },
      },
    });
  }
}
