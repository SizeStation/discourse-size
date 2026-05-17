import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";

export default class DiscourseSizeDailyQuests extends Component {
  @service siteSettings;
  @service currentUser;

  @tracked loading = true;
  @tracked quests = [];
  @tracked dailyRewardStatus = "available";
  @tracked canReroll = false;
  @tracked bonusCollected = false;
  @tracked extraRewardAmount = 0;
  @tracked collectingDaily = false;
  @tracked collectingQuest = false;
  @tracked collectingBonus = false;
  @tracked rerolling = false;
  @tracked canGetNewQuests = false;
  @tracked nextRerollAt = null;
  @tracked rerollTimerText = "";
  @tracked gettingNewQuests = false;

  _timer = null;

  constructor() {
    super(...arguments);
    this.loadQuests();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this._timer) {
      clearInterval(this._timer);
    }
  }

  async loadQuests() {
    try {
      const response = await ajax("/size/quests");
      this.quests = response.quests;
      this.dailyRewardStatus = response.daily_reward_status;
      this.canReroll = response.can_reroll;
      this.canGetNewQuests = response.can_get_new_quests;
      this.nextRerollAt = response.next_reroll_at;
      this.extraRewardAmount = response.extra_reward_amount;
      this.bonusCollected = response.bonus_collected;
      this.loading = false;

      this.startRerollTimer();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  startRerollTimer() {
    if (this._timer) {
      clearInterval(this._timer);
    }

    if (this.canReroll || !this.nextRerollAt) {
      this.rerollTimerText = "";
      return;
    }

    const updateTimer = () => {
      const now = new Date();
      const target = new Date(this.nextRerollAt);
      const diff = target - now;

      if (diff <= 0) {
        this.rerollTimerText = "";
        this.canReroll = true;
        clearInterval(this._timer);
        return;
      }

      const hours = Math.floor(diff / 3600000);
      const minutes = Math.floor((diff % 3600000) / 60000);
      const seconds = Math.floor((diff % 60000) / 1000);

      this.rerollTimerText = I18n.t("js.discourse_size.quests.next_reroll_in", {
        time: `${hours}h ${minutes}m ${seconds}s`,
      });
    };

    updateTimer();
    this._timer = setInterval(updateTimer, 1000);
  }

  get allQuestsCompleted() {
    return this.quests.length > 0 && this.quests.every((q) => q.collected);
  }

  @action
  async collectDailyReward() {
    this.collectingDaily = true;
    try {
      const response = await ajax("/size/shop/claim_reward", { type: "POST" });
      if (response.success) {
        this.dailyRewardStatus = "collected";
        this.currentUser.set("discourse_size_points", response.current_points);
        this.loadQuests();
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.collectingDaily = false;
    }
  }

  @action
  async collectQuest(quest) {
    this.collectingQuest = true;
    try {
      const response = await ajax("/size/quests/collect", {
        type: "POST",
        data: { quest_id: quest.id },
      });
      if (response.success) {
        this.currentUser.set("discourse_size_points", response.current_points);
        await this.loadQuests();
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.collectingQuest = false;
    }
  }

  @action
  async collectBonusReward() {
    this.collectingBonus = true;
    try {
      const response = await ajax("/size/quests/collect_bonus", { type: "POST" });
      if (response.success) {
        this.bonusCollected = true;
        this.currentUser.set("discourse_size_points", response.current_points);
        this.loadQuests();
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.collectingBonus = false;
    }
  }

  @action
  async rerollQuests() {
    this.rerolling = true;
    try {
      const response = await ajax("/size/quests/reroll", { type: "POST" });
      if (response?.success) {
        this.quests = response.quests;
        this.canReroll = false;
        this.startRerollTimer();
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.rerolling = false;
    }
  }

  @action
  async getNewQuests() {
    this.gettingNewQuests = true;
    try {
      const response = await ajax("/size/quests/get_new", { type: "POST" });
      if (response?.success) {
        this.quests = response.quests;
        this.canGetNewQuests = false;
        this.canReroll = true;
        this.startRerollTimer();
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.gettingNewQuests = false;
    }
  }

  @action
  async adminResetQuests() {
    try {
      await ajax("/size/admin/reset_quests", { type: "POST" });
      this.loadQuests();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  getQuestName(quest) {
    return I18n.t(`discourse_size.quests.names.${quest.quest_id}`, { count: quest.target_count });
  }

  getQuestProgress(quest) {
    return Math.min(100, (quest.current_count / quest.target_count) * 100);
  }

  get inviteReward() {
    return this.siteSettings.discourse_size_points_per_invite;
  }

  get invitedReward() {
    return this.siteSettings.discourse_size_points_per_invited;
  }
}
